import { readFileSync } from 'node:fs'

import type { LlmRequest } from '@google/adk'
import { evalCasesSchema, prEvent, type PrEvent } from '@scope/contracts'
import { describe, expect, it } from 'vitest'

import { createWorker, ScriptedLlm } from './app.ts'
import { VertexClaude, type ClaudeClient } from './claude.ts'
import { runEval, summarize } from './eval.ts'
import { graphOf } from './graph.ts'
import { isClaudeModel, vertexModel } from './models.ts'
import { WORKER } from './strings.ts'
import { buildTriage, gatherFacts, runTriage } from './triage.ts'

const event: PrEvent = prEvent.schema.parse({
  source: 'github',
  deliveryId: 'd1',
  repository: 'acme/app',
  pullRequest: 3,
  action: 'opened',
  title: 'docs: typo',
  changedFiles: ['README.md', 'docs/guide.mdx']
})

const promptOf = (request?: LlmRequest) =>
  (request?.contents ?? []).flatMap((content) => content.parts ?? []).map((part) => part.text ?? '').join('')

const approving = () =>
  new ScriptedLlm(() => JSON.stringify({ verdict: 'approve', reason: 'documentation only' }))

const push = (data: Uint8Array) =>
  Buffer.from(
    JSON.stringify({
      message: { data: Buffer.from(data).toString('base64'), messageId: '1' },
      subscription: 's'
    })
  )

describe('the code step', () => {
  it('decides docsOnly from the changed files, without a model', () => {
    expect(gatherFacts(event).docsOnly).toBe(true)
    expect(gatherFacts({ ...event, changedFiles: ['src/a.ts', 'README.md'] }).docsOnly).toBe(false)
    expect(gatherFacts({ ...event, changedFiles: [] }).docsOnly).toBe(false)
  })

  it('truncates the body it hands to the judge', () => {
    expect(gatherFacts({ ...event, body: 'x'.repeat(5000) }).body).toHaveLength(2000)
  })
})

describe('the triage workflow', () => {
  it('runs the code step, then the judge with the code step output', async () => {
    const judge = approving()
    const verdict = await runTriage(buildTriage(judge), event)
    expect(verdict).toEqual({ verdict: 'approve', reason: 'documentation only' })
    const [request] = judge.requests
    expect(promptOf(request)).toContain('"docsOnly":true')
  })

  it('fails when the judge answers outside the contract', async () => {
    const judge = new ScriptedLlm(() => JSON.stringify({ verdict: 'maybe', reason: 'unsure' }))
    await expect(runTriage(buildTriage(judge), event)).rejects.toThrow()
  })
})

describe('the worker', () => {
  const request = (body: Buffer) => ({ method: 'POST', path: '/', headers: {}, body })

  it('answers 200 with the verdict of a valid push', async () => {
    const handle = createWorker({ judge: approving() })
    const reply = await handle(request(push(prEvent.encode(event))))
    expect(reply.status).toBe(200)
    expect(JSON.parse(reply.body)).toMatchObject({ verdict: 'approve' })
  })

  it('answers 500 to a message that breaks the contract, so Pub/Sub retries and then dead-letters it', async () => {
    const handle = createWorker({ judge: approving() })
    const reply = await handle(request(push(new TextEncoder().encode('{"deliveryId":""}'))))
    expect(reply.status).toBe(500)
  })

  it('answers 404 elsewhere', async () => {
    const handle = createWorker({ judge: approving() })
    expect((await handle({ method: 'GET', path: '/', headers: {}, body: Buffer.alloc(0) })).status).toBe(404)
  })
})

describe('the graph export', () => {
  it('lists nodes and edges in the shape React Flow reads', () => {
    expect(graphOf(buildTriage('gemini-2.5-flash'))).toEqual({
      name: 'triage',
      nodes: [
        { id: '__START__', type: 'start', data: { label: '__START__', kind: 'start' }, position: { x: 0, y: 0 } },
        { id: 'facts', type: 'code', data: { label: 'facts', kind: 'code' }, position: { x: 240, y: 0 } },
        { id: 'judge', type: 'judge', data: { label: 'judge', kind: 'judge' }, position: { x: 480, y: 0 } }
      ],
      edges: [
        { id: '__START__->facts', source: '__START__', target: 'facts' },
        { id: 'facts->judge', source: 'facts', target: 'judge' }
      ]
    })
  })
})

describe('the eval harness', () => {
  it('scores the shipped cases against a model and reports each', async () => {
    const cases = evalCasesSchema.parse(JSON.parse(readFileSync(WORKER.files.evalCases, 'utf8')))
    const model = new ScriptedLlm((request) =>
      JSON.stringify({
        verdict: promptOf(request).includes('"docsOnly":true') ? 'approve' : 'review',
        reason: 'by the facts'
      })
    )
    const results = await runEval(cases, buildTriage(model))
    expect(results.map((result) => result.passed)).toEqual([true, true])
    expect(summarize(results)).toBe('2/2 passed')
  })

  it('reports a case the model gets wrong', async () => {
    const cases = evalCasesSchema.parse(JSON.parse(readFileSync(WORKER.files.evalCases, 'utf8')))
    const results = await runEval(cases, buildTriage(approving()))
    expect(results.map((result) => result.passed)).toEqual([true, false])
    expect(results[1]?.line).toBe('FAIL change to the authentication code: want review, got approve')
  })
})

describe('Claude on Vertex AI', () => {
  const client = (text: string, seen: unknown[] = []): ClaudeClient => ({
    messages: {
      create: async (params) => {
        seen.push(params)
        return { content: [{ type: 'text', text }] }
      }
    }
  })

  it('answers a judge step, with the output schema in the system prompt', async () => {
    const seen: unknown[] = []
    const claude = new VertexClaude({
      model: 'claude-sonnet-4-5',
      client: client(JSON.stringify({ verdict: 'review', reason: 'touches auth' }), seen)
    })
    const verdict = await runTriage(buildTriage(claude), event)
    expect(verdict.verdict).toBe('review')
    expect(JSON.stringify(seen)).toContain('Reply with only JSON that matches this schema')
  })

  it('is chosen by the model name, Gemini otherwise, both on Vertex AI', () => {
    const env = {
      GOOGLE_CLOUD_PROJECT: 'p',
      GOOGLE_CLOUD_LOCATION: 'us-central1',
      CLAUDE_LOCATION: 'us-east5'
    }
    expect(vertexModel('claude-sonnet-4-5', env)).toBeInstanceOf(VertexClaude)
    expect(isClaudeModel('gemini-2.5-flash')).toBe(false)
  })
})
