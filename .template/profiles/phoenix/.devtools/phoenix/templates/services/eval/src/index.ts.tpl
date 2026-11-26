import { serve, startTelemetry } from '@scope/platform'
import { judgeModelName, vertexModel } from '@scope/worker'

import { createEvalWorker } from './app.ts'
import { EVAL } from './strings.ts'

const required = (name: string): string => {
  const value = process.env[name]
  if (!value) throw new Error(EVAL.messages.missing(name))
  return value
}

startTelemetry('eval')

serve(
  createEvalWorker({
    judge: vertexModel(judgeModelName()),
    phoenix: { url: required(EVAL.env.phoenixUrl), apiKey: required(EVAL.env.phoenixKey) }
  })
)
