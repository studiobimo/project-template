import { createHmac, timingSafeEqual } from 'node:crypto'

import { INGRESS } from './strings.ts'

const hmac = (secret: string, payload: string | Buffer) =>
  createHmac('sha256', secret).update(payload).digest('hex')

function safeEqual(received: string | undefined, expected: string): boolean {
  if (received === undefined) return false
  const left = Buffer.from(received)
  const right = Buffer.from(expected)
  return left.length === right.length && timingSafeEqual(left, right)
}

export const githubSignature = (secret: string, body: Buffer) =>
  `${INGRESS.signatures.githubPrefix}${hmac(secret, body)}`

export const verifyGithub = (secret: string, signature: string | undefined, body: Buffer) =>
  safeEqual(signature, githubSignature(secret, body))

export const slackSignature = (secret: string, timestamp: string, body: Buffer) =>
  `${INGRESS.signatures.slackVersion}=${hmac(
    secret,
    `${INGRESS.signatures.slackVersion}:${timestamp}:${body.toString()}`
  )}`

export function verifySlack(
  secret: string,
  signature: string | undefined,
  timestamp: string | undefined,
  body: Buffer,
  nowSeconds: number
): boolean {
  if (timestamp === undefined) return false
  const skew = Math.abs(nowSeconds - Number(timestamp))
  if (!(skew <= INGRESS.limits.slackSkewSeconds)) return false
  return safeEqual(signature, slackSignature(secret, timestamp, body))
}
