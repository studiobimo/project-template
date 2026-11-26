import { PGlite } from '@electric-sql/pglite'
import { PGLiteSocketServer } from '@electric-sql/pglite-socket'
import { createEvent, DatabaseSessionService, InMemorySessionService } from '@google/adk'
import { prEvent, type PrEvent } from '@scope/contracts'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'

import { createWorker, ScriptedLlm } from './app.ts'
import { SESSIONS, sessionService } from './sessions.ts'

const database = new PGlite()
const server = new PGLiteSocketServer({ db: database, port: 0, host: '127.0.0.1', maxConnections: 8 })
let port = 0

const connection = () => ({
  [SESSIONS.env.database]: 'postgres',
  [SESSIONS.env.user]: 'postgres',
  [SESSIONS.env.password]: 'postgres',
  [SESSIONS.env.poolSize]: '1'
})

const direct = () => ({
  ...connection(),
  [SESSIONS.env.host]: '127.0.0.1',
  [SESSIONS.env.port]: String(port)
})

const event: PrEvent = prEvent.schema.parse({
  source: 'github',
  deliveryId: 'sessions-1',
  repository: 'acme/app',
  pullRequest: 4,
  action: 'opened',
  title: 'docs: typo',
  changedFiles: ['README.md']
})

beforeAll(async () => {
  await server.start()
  port = Number(server.getServerConn().split(':').at(-1))
})

afterAll(async () => {
  await server.stop()
  await database.close()
})

describe('the session service', () => {
  it('is in memory when no database is configured', async () => {
    expect(await sessionService({})).toBeInstanceOf(InMemorySessionService)
  })

  it('is Postgres when a host is configured, and keeps a session across instances', async () => {
    const first = await sessionService(direct())
    expect(first).toBeInstanceOf(DatabaseSessionService)
    const created = await first.createSession({
      appName: 'app',
      userId: 'u',
      sessionId: 'paused',
      state: { step: 'waiting' }
    })
    await first.appendEvent({
      session: created,
      event: createEvent({ author: 'user', content: { role: 'user', parts: [{ text: 'hello' }] } })
    })

    const second = await sessionService(direct())
    const resumed = await second.getSession({ appName: 'app', userId: 'u', sessionId: 'paused' })
    expect(resumed?.state).toEqual({ step: 'waiting' })
    expect(resumed?.events).toHaveLength(1)
  })

  it('connects through the Cloud SQL connector when an instance is configured', async () => {
    const asked: string[] = []
    const connect = async (instance: string) => {
      asked.push(instance)
      return { host: '127.0.0.1', port }
    }
    const sessions = await sessionService(
      { ...connection(), [SESSIONS.env.instance]: 'project:region:instance' },
      connect
    )
    expect(asked).toEqual(['project:region:instance'])
    expect(sessions).toBeInstanceOf(DatabaseSessionService)
  })
})

describe('the worker with a database session service', () => {
  it('runs its workflow in a session named after the delivery', async () => {
    const sessions = await sessionService(direct())
    const judge = new ScriptedLlm(() => JSON.stringify({ verdict: 'approve', reason: 'docs only' }))
    const worker = createWorker({ judge, sessions })
    const data = Buffer.from(prEvent.encode(event)).toString('base64')
    const reply = await worker({
      method: 'POST',
      path: '/',
      headers: {},
      body: Buffer.from(JSON.stringify({ message: { data, messageId: '1' }, subscription: 's' }))
    })
    expect(reply.status).toBe(200)
    const stored = await sessions.getSession({
      appName: 'adk-worker',
      userId: 'push',
      sessionId: event.deliveryId
    })
    expect(stored?.events.length).toBeGreaterThan(0)
  })
})
