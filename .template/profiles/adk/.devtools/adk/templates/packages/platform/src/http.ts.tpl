import { createServer, type Server } from 'node:http'

import { HTTP } from './strings.ts'
import { flushTelemetry } from './telemetry.ts'

export interface HttpRequest {
  method: string
  path: string
  headers: Record<string, string | undefined>
  body: Buffer
}

export interface Reply {
  status: number
  body: string
}

export type Handler = (request: HttpRequest) => Promise<Reply>

const flatten = (headers: Record<string, string | string[] | undefined>) =>
  Object.fromEntries(Object.entries(headers).map(([name, value]) => [name, [value].flat().join(',')]))

const flushQuietly = () =>
  flushTelemetry().catch((error: unknown) => console.error(HTTP.messages.flushFailed, error))

export function serve(
  handler: Handler,
  port = Number(process.env.PORT ?? HTTP.defaultPort)
): Server {
  const server = createServer((request, response) => {
    const chunks: Buffer[] = []
    let size = 0
    let tooLarge = false
    request.on('data', (chunk: Buffer) => {
      if (tooLarge) return
      size += chunk.length
      if (size <= HTTP.limits.bodyBytes) {
        chunks.push(chunk)
        return
      }
      tooLarge = true
      chunks.length = 0
      response
        .writeHead(HTTP.statuses.tooLarge, { connection: 'close' })
        .end(() => request.destroy())
    })
    request.on('error', (error: Error) => {
      console.error(HTTP.messages.failed, error)
      response.destroy()
    })
    request.on('end', () => {
      if (tooLarge) return
      handler({
        method: request.method ?? 'GET',
        path: new URL(request.url ?? '/', 'http://localhost').pathname,
        headers: flatten(request.headers),
        body: Buffer.concat(chunks)
      })
        .then(async (reply) => {
          await flushQuietly()
          return reply
        })
        .then(({ status, body }) => response.writeHead(status).end(body))
        .catch((error: unknown) => {
          console.error(HTTP.messages.failed, error)
          response.writeHead(HTTP.statuses.failed).end()
        })
    })
  })
  server.listen(port, () => console.log(HTTP.messages.listening(port)))
  process.on('SIGTERM', () => server.close(() => process.exit(0)))
  return server
}
