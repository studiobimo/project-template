import { describe, expect, it } from 'vitest'

import { MemoryBus } from './memory-bus.ts'

const message = (orderingKey: string, text: string) => ({
  data: new TextEncoder().encode(text),
  orderingKey,
  attributes: {}
})

const textOf = (body: string) =>
  Buffer.from(JSON.parse(body).message.data, 'base64').toString()

describe('MemoryBus', () => {
  it('delivers the messages of one ordering key one at a time, in order', async () => {
    const bus = new MemoryBus()
    const seen: string[] = []
    bus.subscribe('t', async (body) => {
      seen.push(`start ${textOf(body)}`)
      await new Promise((resolve) => setTimeout(resolve, textOf(body) === 'a' ? 20 : 0))
      seen.push(`end ${textOf(body)}`)
      return { status: 200, body: '' }
    })
    await bus.publish('t', message('k', 'a'))
    await bus.publish('t', message('k', 'b'))
    await bus.idle()
    expect(seen).toEqual(['start a', 'end a', 'start b', 'end b'])
  })

  it('redelivers a nacked message, then dead-letters it, and carries on', async () => {
    const bus = new MemoryBus()
    bus.subscribe('t', async (body) => ({ status: textOf(body) === 'bad' ? 500 : 200, body: '' }))
    await bus.publish('t', message('k', 'bad'))
    await bus.publish('t', message('k', 'good'))
    await bus.idle()
    expect(bus.deliveries.filter(({ reply }) => reply.status === 500)).toHaveLength(5)
    expect(bus.deadLetters).toHaveLength(1)
    expect(bus.deliveries.at(-1)?.reply.status).toBe(200)
  })

  it('hands the subscriber a Pub/Sub push body', async () => {
    const bus = new MemoryBus()
    let body = ''
    bus.subscribe('t', async (received) => {
      body = received
      return { status: 200, body: '' }
    })
    await bus.publish('t', { ...message('k', 'x'), attributes: { traceparent: 'p' } })
    await bus.idle()
    expect(JSON.parse(body).message).toMatchObject({
      orderingKey: 'k',
      attributes: { traceparent: 'p' }
    })
  })
})
