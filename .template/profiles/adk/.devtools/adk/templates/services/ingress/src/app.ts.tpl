import {
  githubPullRequestSchema,
  orderingKeyOf,
  prEvent,
  pullRequestReferenceSchema,
  slackCommandSchema,
  slackUrlVerificationSchema,
  type PrEvent
} from '@scope/contracts'
import {
  inSpan,
  publishTopic,
  type HttpRequest,
  type Publisher,
  type Reply
} from '@scope/platform'

import { verifyGithub, verifySlack } from './signatures.ts'
import { INGRESS } from './strings.ts'

export { githubSignature, slackSignature } from './signatures.ts'

export interface IngressConfig {
  publisher: Publisher
  githubSecret: string
  slackSecret: string
  now?: () => number
}

const reply = (status: number, body: string): Reply => ({ status, body })
const json = (value: unknown): Reply => reply(200, JSON.stringify(value))

async function withDeadline<T>(work: Promise<T>, milliseconds: number) {
  let timer: NodeJS.Timeout | undefined
  const expired = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(INGRESS.messages.unavailable)), milliseconds)
  })
  try {
    return await Promise.race([work, expired])
  } finally {
    clearTimeout(timer)
  }
}

const queue = (config: IngressConfig, event: PrEvent, deadline: number) =>
  withDeadline(
    publishTopic(config.publisher, prEvent, event, orderingKeyOf(event)).then(() =>
      reply(200, INGRESS.messages.queued)
    ),
    deadline
  )

function github(config: IngressConfig, { headers, body }: HttpRequest): Promise<Reply> | Reply {
  if (!verifyGithub(config.githubSecret, headers[INGRESS.headers.githubSignature], body)) {
    return reply(401, INGRESS.messages.unauthorized)
  }
  const kind = headers[INGRESS.headers.githubEvent]
  if (kind === INGRESS.events.githubPing) return reply(200, INGRESS.messages.pong)
  if (kind !== INGRESS.events.githubPullRequest) return reply(202, INGRESS.messages.ignored)
  const parsed = githubPullRequestSchema.safeParse(safeJson(body))
  if (!parsed.success) return reply(400, INGRESS.messages.badRequest)
  const { action, number, pull_request, repository } = parsed.data
  return queue(
    config,
    prEvent.schema.parse({
      source: 'github',
      deliveryId: headers[INGRESS.headers.githubDelivery] ?? `${repository.full_name}#${number}`,
      repository: repository.full_name,
      pullRequest: number,
      action,
      title: pull_request.title,
      body: pull_request.body ?? ''
    }),
    INGRESS.limits.githubAckMs
  )
}

function slack(config: IngressConfig, { headers, body }: HttpRequest): Promise<Reply> | Reply {
  const now = (config.now ?? Date.now)() / 1000
  const signature = headers[INGRESS.headers.slackSignature]
  const timestamp = headers[INGRESS.headers.slackTimestamp]
  if (!verifySlack(config.slackSecret, signature, timestamp, body, now)) {
    return reply(401, INGRESS.messages.unauthorized)
  }
  const verification = slackUrlVerificationSchema.safeParse(safeJson(body))
  if (verification.success) return reply(200, verification.data.challenge)
  const command = slackCommandSchema.safeParse(Object.fromEntries(new URLSearchParams(body.toString())))
  if (!command.success) return reply(400, INGRESS.messages.badRequest)
  const target = pullRequestReferenceSchema.safeParse(command.data.text.trim())
  if (!target.success) return json({ response_type: 'ephemeral', text: INGRESS.messages.usage })
  return queue(
    config,
    prEvent.schema.parse({
      source: 'slack',
      deliveryId: command.data.trigger_id,
      action: 'requested',
      ...target.data
    }),
    INGRESS.limits.slackAckMs
  ).then(() => json({ response_type: 'ephemeral', text: INGRESS.messages.queued }))
}

function safeJson(body: Buffer): unknown {
  try {
    return JSON.parse(body.toString())
  } catch {
    return undefined
  }
}

export function createIngress(config: IngressConfig) {
  const routes: Record<string, (request: HttpRequest) => Promise<Reply> | Reply> = {
    [INGRESS.paths.github]: (request) => github(config, request),
    [INGRESS.paths.slack]: (request) => slack(config, request)
  }
  return async (request: HttpRequest): Promise<Reply> => {
    const route = routes[request.path]
    if (request.method !== 'POST' || !route) return reply(404, INGRESS.messages.notFound)
    return inSpan(INGRESS.spans.request(request.path), async () => {
      try {
        return await route(request)
      } catch {
        return reply(503, INGRESS.messages.unavailable)
      }
    })
  }
}
