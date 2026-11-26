import { createServer, type IncomingMessage, type Server } from 'node:http'
import type { AddressInfo } from 'node:net'

import { InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { prEvent, runCompleted, runScoreSchema } from '@scope/contracts'
import { MemoryBus, publishTopic, startTelemetry } from '@scope/platform'
import { createWorker, publishRunCompleted, ScriptedLlm } from '@scope/worker'
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest'

import { createEvalWorker } from './app.ts'

const KEY = 'phoenix-test-key'
const exporter = new InMemorySpanExporter()

interface Seen {
  method: string
  url: string
  headers: IncomingMessage['headers']
  body: { data: Array<Record<string, unknown>> }
}

interface Reply {
  status: number
  type: string
  body: string
}

const JSON_REPLY: Reply = { status: 200, type: 'application/json', body: '{"data":[]}' }
const seen: Seen[] = []
let reply: Reply = JSON_REPLY
let phoenix: Server
let url: string

const triage = JSON.stringify({ verdict: 'approve', reason: 'documentation only' })
const score = { label: 'good', score: 0.9, explanation: 'docs only, so approve fits' }

const event = prEvent.schema.parse({
  source: 'github',
  deliveryId: 'delivery-1',
  repository: 'acme/app',
  pullRequest: 3,
  action: 'opened',
  title: 'docs: typo',
  changedFiles: ['README.md']
})

function setup(judge = new ScriptedLlm(() => JSON.stringify(score))) {
  const bus = new MemoryBus()
  const worker = createWorker({
    judge: new ScriptedLlm(() => triage),
    onVerdict: publishRunCompleted(bus)
  })
  const scorer = createEvalWorker({ judge, phoenix: { url, apiKey: KEY } })
  const push = (handle: typeof worker) => (body: string) =>
    handle({ method: 'POST', path: '/', headers: {}, body: Buffer.from(body) })
  bus.subscribe(prEvent.name, push(worker))
  bus.subscribe(runCompleted.name, push(scorer))
  return bus
}

async function settle(bus: MemoryBus) {
  let known = -1
  while (known !== bus.deliveries.length) {
    known = bus.deliveries.length
    await bus.idle()
  }
}

async function runThrough(bus: MemoryBus) {
  await publishTopic(bus, prEvent, event, 'acme/app#3')
  await settle(bus)
}

beforeAll(async () => {
  startTelemetry('test', [{ spanProcessors: [new SimpleSpanProcessor(exporter)] }])
  phoenix = createServer((request, response) => {
    const chunks: Buffer[] = []
    request.on('data', (chunk: Buffer) => chunks.push(chunk))
    request.on('end', () => {
      seen.push({
        method: request.method ?? '',
        url: request.url ?? '',
        headers: request.headers,
        body: JSON.parse(Buffer.concat(chunks).toString() || '{"data":[]}')
      })
      response.writeHead(reply.status, { 'content-type': reply.type }).end(reply.body)
    })
  })
  await new Promise<void>((resolve) => phoenix.listen(0, '127.0.0.1', resolve))
  url = `http://127.0.0.1:${(phoenix.address() as AddressInfo).port}`
})

afterAll(() => new Promise((resolve) => phoenix.close(resolve)))

beforeEach(() => {
  exporter.reset()
  seen.length = 0
  reply = JSON_REPLY
})

describe('run.completed to a Phoenix annotation', () => {
  it('scores the run with the judge and posts the annotation with the API key', async () => {
    const bus = setup()
    await runThrough(bus)

    expect(seen).toHaveLength(1)
    const [request] = seen
    expect(request?.method).toBe('POST')
    expect(request?.url).toBe('/v1/span_annotations?sync=true')
    expect(request?.headers.authorization).toBe(`Bearer ${KEY}`)
    expect(request?.headers['content-type']).toContain('application/json')
    const [annotation] = request?.body.data ?? []
    expect(annotation).toEqual({
      name: 'verdict-quality',
      annotator_kind: 'LLM',
      span_id: expect.stringMatching(/^[0-9a-f]{16}$/),
      result: score,
      identifier: ''
    })
    expect(runScoreSchema.parse(annotation?.result)).toEqual(score)
    expect(bus.deadLetters).toHaveLength(0)
  })

  it('annotates the worker span that handled the run, in the run trace', async () => {
    const bus = setup()
    await runThrough(bus)

    const spans = exporter.getFinishedSpans()
    const worker = spans.find((span) => span.name === 'pr-events process')
    expect(seen[0]?.body.data[0]?.span_id).toBe(worker?.spanContext().spanId)
    const traces = new Set(spans.map((span) => span.spanContext().traceId))
    expect(traces.size).toBe(1)
  })

  it('hands the judge the pull request and the first verdict', async () => {
    const judge = new ScriptedLlm(() => JSON.stringify(score))
    await runThrough(setup(judge))
    const prompt = JSON.stringify(judge.requests[0]?.contents)
    expect(prompt).toContain('docs: typo')
    expect(prompt).toContain('documentation only')
  })

  it('retries a run when Phoenix answers with a page instead of JSON', async () => {
    reply = { status: 200, type: 'text/html', body: '<html>Sign in</html>' }
    const bus = setup()
    await runThrough(bus)
    expect(seen.length).toBeGreaterThan(1)
    expect(bus.deadLetters).toHaveLength(1)
  })

  it('retries a run when Phoenix has not ingested the span yet', async () => {
    reply = { status: 404, type: 'application/json', body: '{"detail":"span not found"}' }
    const bus = setup()
    await runThrough(bus)
    expect(bus.deadLetters).toHaveLength(1)
  })

  it('answers 500 to a judge that breaks the score contract', async () => {
    const bus = setup(new ScriptedLlm(() => JSON.stringify({ label: 'great', score: 2 })))
    await runThrough(bus)
    expect(seen).toHaveLength(0)
    expect(bus.deadLetters).toHaveLength(1)
  })
})
