import { Gemini, type BaseLlm } from '@google/adk'

import { VertexClaude } from './claude.ts'
import { WORKER } from './strings.ts'

export const judgeModelName = (env: NodeJS.ProcessEnv = process.env) =>
  env[WORKER.env.judgeModel] ?? WORKER.models.judge

export const isClaudeModel = (name: string) => name.startsWith(WORKER.models.claudePrefix)

export function vertexModel(name: string, env: NodeJS.ProcessEnv = process.env): BaseLlm {
  const project = env[WORKER.env.project]
  const location = env[WORKER.env.location] ?? WORKER.models.defaultLocation
  const claudeLocation = env[WORKER.env.claudeLocation] ?? WORKER.models.defaultClaudeLocation
  return isClaudeModel(name)
    ? new VertexClaude({ model: name, project, location: claudeLocation })
    : new Gemini({ model: name, vertexai: true, project, location })
}
