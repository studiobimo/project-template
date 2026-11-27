import { prEvent, type PrEvent, type TriageVerdict } from '@scope/contracts'
import { consumeTopic, type HttpRequest, type Reply } from '@scope/platform'

import { WORKER } from './strings.ts'
import { buildTriage, runTriage, type Judge } from './triage.ts'

export { ScriptedLlm } from './scripted-llm.ts'
export { buildTriage, runTriage } from './triage.ts'
export type { Judge } from './triage.ts'

export interface WorkerConfig {
  judge: Judge
  onVerdict?: (event: PrEvent, verdict: TriageVerdict) => void
}

export function createWorker({ judge, onVerdict }: WorkerConfig) {
  const triage = buildTriage(judge)
  return async ({ method, path, body }: HttpRequest): Promise<Reply> => {
    if (method !== 'POST' || path !== WORKER.paths.push) {
      return { status: 404, body: WORKER.messages.notFound }
    }
    try {
      return await consumeTopic(prEvent, body.toString(), async (event) => {
        const verdict = await runTriage(triage, event)
        onVerdict?.(event, verdict)
        return { status: 200, body: JSON.stringify(verdict) }
      })
    } catch (error) {
      console.error(error)
      return { status: 500, body: WORKER.messages.badPush }
    }
  }
}
