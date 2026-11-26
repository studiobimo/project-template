import type { Server } from 'node:http'
import type { AddressInfo } from 'node:net'

import { afterEach, describe, expect, it, vi } from 'vitest'

import { serve, type Handler } from './http.ts'
import { HTTP } from './strings.ts'

const servers: Server[] = []

async function start(handler: Handler): Promise<string> {
  const server = serve(handler, 0)
  servers.push(server)
  await new Promise((resolve) => server.once('listening', resolve))
  return `http://127.0.0.1:${(server.address() as AddressInfo).port}`
}

afterEach(() => {
  for (const server of servers.splice(0)) server.close()
})

describe('serve', () => {
  it('hands the handler the whole body and answers with its reply', async () => {
    const url = await start(async ({ body }) => ({ status: 200, body: body.toString().toUpperCase() }))
    const response = await fetch(url, { method: 'POST', body: 'hello' })
    expect(response.status).toBe(200)
    expect(await response.text()).toBe('HELLO')
  })

  it('answers 413 past the body limit without calling the handler', async () => {
    const handler = vi.fn<Handler>(async () => ({ status: 200, body: '' }))
    const url = await start(handler)
    const response = await fetch(url, { method: 'POST', body: Buffer.alloc(HTTP.limits.bodyBytes + 1) })
    expect(response.status).toBe(HTTP.statuses.tooLarge)
    expect(handler).not.toHaveBeenCalled()
  })

  it('answers 500 when the handler fails', async () => {
    const url = await start(async () => {
      throw new Error('boom')
    })
    vi.spyOn(console, 'error').mockImplementation(() => undefined)
    const response = await fetch(url, { method: 'POST', body: 'x' })
    expect(response.status).toBe(HTTP.statuses.failed)
  })
})
