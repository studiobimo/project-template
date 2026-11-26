import { runCompleted } from '@scope/contracts'
import { consumeTopic, type HttpRequest, type Reply } from '@scope/platform'
import type { Judge } from '@scope/worker'

import { buildScorer, scoreRun } from './judge.ts'
import { annotateSpan, type PhoenixConfig } from './phoenix.ts'
import { EVAL } from './strings.ts'

export interface EvalConfig {
  judge: Judge
  phoenix: PhoenixConfig
}

export function createEvalWorker({ judge, phoenix }: EvalConfig) {
  const scorer = buildScorer(judge)
  return async ({ method, path, body }: HttpRequest): Promise<Reply> => {
    if (method !== 'POST' || path !== EVAL.paths.push) {
      return { status: 404, body: EVAL.messages.notFound }
    }
    try {
      return await consumeTopic(runCompleted, body.toString(), async (completed) => {
        const score = await scoreRun(scorer, completed)
        await annotateSpan(phoenix, completed.spanId, score)
        return { status: 200, body: JSON.stringify(score) }
      })
    } catch (error) {
      console.error(error)
      return { status: 500, body: EVAL.messages.badPush }
    }
  }
}
