import { prEvent } from '@scope/contracts'
import { MemoryBus, type HttpRequest, type Message, type Publisher } from '@scope/platform'
import { describe, expect, it, vi } from 'vitest'

import { createIngress } from './app.ts'
import { githubSignature, slackSignature } from './signatures.ts'
import { INGRESS } from './strings.ts'

const SECRETS = { githubSecret: 'gh', slackSecret: 'sl' }
const NOW = 1_700_000_000

const pullRequest = Buffer.from(
  JSON.stringify({
    action: 'opened',
    number: 7,
    pull_request: { title: 'Fix', body: null },
    repository: { full_name: 'acme/app' }
  })
)

const githubRequest = (body: Buffer, event = 'pull_request', secret = 'gh'): HttpRequest => ({
  method: 'POST',
  path: INGRESS.paths.github,
  headers: {
    [INGRESS.headers.githubSignature]: githubSignature(secret, body),
    [INGRESS.headers.githubEvent]: event,
    [INGRESS.headers.githubDelivery]: 'delivery-1'
  },
  body
})

const slackRequest = (text: string, age = 0): HttpRequest => {
  const body = Buffer.from(new URLSearchParams({ trigger_id: 't1', text }).toString())
  const timestamp = String(NOW - age)
  return {
    method: 'POST',
    path: INGRESS.paths.slack,
    headers: {
      [INGRESS.headers.slackSignature]: slackSignature('sl', timestamp, body),
      [INGRESS.headers.slackTimestamp]: timestamp
    },
    body
  }
}

const setup = (publisher: Publisher = new MemoryBus()) => ({
  publisher,
  handle: createIngress({ publisher, ...SECRETS, now: () => NOW * 1000 })
})

describe('github', () => {
  it('queues a signed pull request event with the pull request as ordering key', async () => {
    const published: Array<{ topic: string; message: Message }> = []
    const { handle } = setup({
      publish: async (topic, message) => {
        published.push({ topic, message })
        return 'id'
      }
    })
    expect((await handle(githubRequest(pullRequest))).status).toBe(200)
    const [{ topic, message }] = published as [(typeof published)[number]]
    expect(topic).toBe('pr-events')
    expect(message.orderingKey).toBe('acme/app#7')
    expect(prEvent.decode(message.data)).toMatchObject({ source: 'github', deliveryId: 'delivery-1' })
  })

  it('refuses a bad signature before reading the body', async () => {
    const { handle } = setup()
    expect((await handle(githubRequest(pullRequest, 'pull_request', 'wrong'))).status).toBe(401)
  })

  it('answers ping, ignores other events and rejects a malformed payload', async () => {
    const { handle } = setup()
    expect((await handle(githubRequest(Buffer.from('{}'), 'ping'))).status).toBe(200)
    expect((await handle(githubRequest(Buffer.from('{}'), 'push'))).status).toBe(202)
    expect((await handle(githubRequest(Buffer.from('{}')))).status).toBe(400)
  })

  it('answers 503 when the queue is slower than GitHub will wait', async () => {
    vi.useFakeTimers()
    const { handle } = setup({ publish: () => new Promise<string>(() => undefined) })
    const pending = handle(githubRequest(pullRequest))
    await vi.advanceTimersByTimeAsync(INGRESS.limits.githubAckMs)
    expect((await pending).status).toBe(503)
    vi.useRealTimers()
  })

  it('answers 503 when publishing fails', async () => {
    const { handle } = setup({ publish: () => Promise.reject(new Error('down')) })
    expect((await handle(githubRequest(pullRequest))).status).toBe(503)
  })
})

describe('slack', () => {
  it('queues a slash command for owner/repo#number', async () => {
    const bus = new MemoryBus()
    const { handle } = setup(bus)
    const result = await handle(slackRequest('acme/app#12'))
    expect(result.status).toBe(200)
    expect(JSON.parse(result.body)).toMatchObject({ text: INGRESS.messages.queued })
  })

  it('explains the usage for text that is not a pull request', async () => {
    const { handle } = setup()
    expect(JSON.parse((await handle(slackRequest('hello'))).body).text).toBe(INGRESS.messages.usage)
  })

  it('refuses a request older than the skew', async () => {
    const { handle } = setup()
    expect((await handle(slackRequest('acme/app#12', 600))).status).toBe(401)
  })

  it('answers the URL verification challenge', async () => {
    const { handle } = setup()
    const body = Buffer.from(JSON.stringify({ type: 'url_verification', challenge: 'abc' }))
    const timestamp = String(NOW)
    const result = await handle({
      method: 'POST',
      path: INGRESS.paths.slack,
      headers: {
        [INGRESS.headers.slackSignature]: slackSignature('sl', timestamp, body),
        [INGRESS.headers.slackTimestamp]: timestamp
      },
      body
    })
    expect(result).toEqual({ status: 200, body: 'abc' })
  })
})

describe('routing', () => {
  it('answers 404 to anything else', async () => {
    const { handle } = setup()
    expect((await handle({ ...githubRequest(pullRequest), path: '/' })).status).toBe(404)
    expect((await handle({ ...githubRequest(pullRequest), method: 'GET' })).status).toBe(404)
  })
})
