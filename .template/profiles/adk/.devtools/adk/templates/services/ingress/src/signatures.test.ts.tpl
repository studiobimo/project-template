import { describe, expect, it } from 'vitest'

import { githubSignature, slackSignature, verifyGithub, verifySlack } from './signatures.ts'

const body = Buffer.from('{"a":1}')

describe('verifyGithub', () => {
  it('accepts the signature of the body', () => {
    expect(verifyGithub('s3cret', githubSignature('s3cret', body), body)).toBe(true)
  })

  it('refuses another secret, another body and a missing header', () => {
    const signature = githubSignature('s3cret', body)
    expect(verifyGithub('other', signature, body)).toBe(false)
    expect(verifyGithub('s3cret', signature, Buffer.from('{}'))).toBe(false)
    expect(verifyGithub('s3cret', undefined, body)).toBe(false)
  })
})

describe('verifySlack', () => {
  const now = 1_700_000_000
  const signed = (timestamp: number) =>
    slackSignature('s3cret', String(timestamp), body)

  it('accepts a fresh, correctly signed request', () => {
    expect(verifySlack('s3cret', signed(now), String(now), body, now)).toBe(true)
  })

  it('refuses a replay older than the skew, and one from the future', () => {
    expect(verifySlack('s3cret', signed(now - 301), String(now - 301), body, now)).toBe(false)
    expect(verifySlack('s3cret', signed(now + 301), String(now + 301), body, now)).toBe(false)
  })

  it('refuses a bad signature, a missing or non-numeric timestamp', () => {
    expect(verifySlack('s3cret', 'v0=00', String(now), body, now)).toBe(false)
    expect(verifySlack('s3cret', signed(now), undefined, body, now)).toBe(false)
    expect(verifySlack('s3cret', signed(now), 'soon', body, now)).toBe(false)
  })
})
