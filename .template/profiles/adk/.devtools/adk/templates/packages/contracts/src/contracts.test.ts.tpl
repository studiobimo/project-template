import { describe, expect, it } from 'vitest'

import { orderingKeyOf, prEvent } from './pr-event.ts'
import { parsePushEnvelope } from './push.ts'
import { pullRequestReferenceSchema } from './webhooks.ts'

const event = {
  source: 'github' as const,
  deliveryId: 'd1',
  repository: 'acme/app',
  pullRequest: 7,
  action: 'opened'
}

describe('prEvent', () => {
  it('fills the defaults and round-trips', () => {
    expect(prEvent.decode(prEvent.encode(event))).toEqual({
      ...event,
      title: '',
      body: '',
      changedFiles: []
    })
  })

  it('refuses a pull request number that is not positive', () => {
    expect(() => prEvent.encode({ ...event, pullRequest: 0 })).toThrow()
  })

  it('orders by repository and pull request', () => {
    expect(orderingKeyOf(event)).toBe('acme/app#7')
  })
})

describe('parsePushEnvelope', () => {
  it('reads a Pub/Sub push body', () => {
    const body = JSON.stringify({ message: { data: 'e30=', messageId: '1' }, subscription: 's' })
    expect(parsePushEnvelope(body).message.attributes).toEqual({})
  })

  it('refuses a body that is not one', () => {
    expect(() => parsePushEnvelope('{}')).toThrow()
  })
})

describe('pullRequestReferenceSchema', () => {
  it('splits owner/name#number', () => {
    expect(pullRequestReferenceSchema.parse('acme/app#12')).toEqual({
      repository: 'acme/app',
      pullRequest: 12
    })
  })

  it('refuses anything else', () => {
    expect(pullRequestReferenceSchema.safeParse('acme/app').success).toBe(false)
  })
})
