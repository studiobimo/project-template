import { githubSignature } from '@scope/ingress'
import { startTelemetry } from '@scope/platform'
import { ScriptedLlm } from '@scope/worker'
import { InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { beforeAll, beforeEach, describe, expect, it } from 'vitest'

import { startLocal } from './local.ts'

const exporter = new InMemorySpanExporter()
const verdict = JSON.stringify({ verdict: 'approve', reason: 'documentation only' })

const signedPullRequest = (number: number) => {
  const body = Buffer.from(
    JSON.stringify({
      action: 'opened',
      number,
      pull_request: { title: 'docs: typo', body: 'Fixes a typo.' },
      repository: { full_name: 'acme/app' }
    })
  )
  return {
    method: 'POST',
    path: '/github',
    headers: {
      'x-hub-signature-256': githubSignature('gh', body),
      'x-github-event': 'pull_request',
      'x-github-delivery': `delivery-${number}`
    },
    body
  }
}

beforeAll(() => {
  startTelemetry('test', [{ spanProcessors: [new SimpleSpanProcessor(exporter)] }])
})

beforeEach(() => exporter.reset())

describe('ingress to worker, in process', () => {
  const setup = () => startLocal(new ScriptedLlm(() => verdict), { githubSecret: 'gh', slackSecret: 'sl' })

  it('carries a signed webhook through the bus to a verdict', async () => {
    const { ingress, bus } = setup()
    expect((await ingress(signedPullRequest(7))).status).toBe(200)
    await bus.idle()
    expect(bus.deliveries).toHaveLength(1)
    expect(JSON.parse(bus.deliveries[0]?.reply.body ?? '')).toMatchObject({ verdict: 'approve' })
    expect(bus.deadLetters).toHaveLength(0)
  })

  it('keeps one trace id from the ingress request to the last workflow step', async () => {
    const { ingress, bus } = setup()
    await ingress(signedPullRequest(7))
    await bus.idle()
    const spans = exporter.getFinishedSpans()
    const names = spans.map((span) => span.name)
    expect(names).toEqual(
      expect.arrayContaining([
        'ingress /github',
        'pr-events publish',
        'pr-events process',
        'workflow triage',
        'step facts'
      ])
    )
    expect(names.some((name) => name.startsWith('invoke_agent'))).toBe(true)
    expect(new Set(spans.map((span) => span.spanContext().traceId)).size).toBe(1)
  })

  it('starts a separate trace for each webhook', async () => {
    const { ingress, bus } = setup()
    await ingress(signedPullRequest(7))
    await ingress(signedPullRequest(8))
    await bus.idle()
    const traces = new Set(exporter.getFinishedSpans().map((span) => span.spanContext().traceId))
    expect(traces.size).toBe(2)
  })

  it('sends the trace context in the message attributes, not in the payload', async () => {
    const { ingress, bus } = setup()
    const seen: Array<Record<string, string>> = []
    const publish = bus.publish.bind(bus)
    bus.publish = (topic, message) => {
      seen.push(message.attributes)
      return publish(topic, message)
    }
    await ingress(signedPullRequest(7))
    await bus.idle()
    expect(seen[0]?.traceparent).toMatch(/^00-[0-9a-f]{32}-[0-9a-f]{16}-0[01]$/)
  })
})
