import { prEvent } from '@scope/contracts'
import { createIngress } from '@scope/ingress'
import { MemoryBus } from '@scope/platform'
import { createWorker, type Judge } from '@scope/worker'

export interface LocalSecrets {
  githubSecret: string
  slackSecret: string
}

export function startLocal(judge: Judge, secrets: LocalSecrets, now?: () => number) {
  const bus = new MemoryBus()
  const worker = createWorker({ judge })
  bus.subscribe(prEvent.name, (body) =>
    worker({ method: 'POST', path: '/', headers: {}, body: Buffer.from(body) })
  )
  return { bus, ingress: createIngress({ publisher: bus, ...secrets, now }) }
}
