import {
  FunctionNode,
  InMemorySessionService,
  LlmAgent,
  Runner,
  START,
  Workflow
} from '@google/adk'
import {
  runCompletedSchema,
  runScoreSchema,
  type RunCompleted,
  type RunScore
} from '@scope/contracts'
import { inSpan } from '@scope/platform'
import type { Judge } from '@scope/worker'

import { EVAL } from './strings.ts'

const prepare = new FunctionNode(EVAL.workflows.prepare, (_context, input: string) =>
  inSpan(EVAL.spans.step(EVAL.workflows.prepare), () => {
    const { event, verdict } = runCompletedSchema.parse(JSON.parse(input))
    return {
      repository: event.repository,
      pullRequest: event.pullRequest,
      title: event.title,
      changedFiles: event.changedFiles,
      verdict
    }
  })
)

export function buildScorer(judge: Judge): Workflow {
  const grade = new LlmAgent({
    name: EVAL.workflows.judge,
    model: judge,
    instruction: EVAL.instructions.judge,
    outputSchema: runScoreSchema,
    includeContents: 'none'
  })
  return new Workflow({
    name: EVAL.workflows.score,
    edges: [[START, prepare, grade]]
  })
}

export function scoreRun(workflow: Workflow, completed: RunCompleted): Promise<RunScore> {
  return inSpan(EVAL.spans.workflow(workflow.name), async () => {
    const runner = new Runner({
      agent: workflow,
      appName: EVAL.app,
      sessionService: new InMemorySessionService(),
      autoCreateSession: true
    })
    let output: unknown
    for await (const step of runner.runAsync({
      userId: EVAL.user,
      sessionId: completed.event.deliveryId,
      newMessage: { role: 'user', parts: [{ text: JSON.stringify(completed) }] }
    })) {
      if (step.author === EVAL.workflows.judge && step.output !== undefined) output = step.output
    }
    if (output === undefined) throw new Error(EVAL.messages.noScore)
    return runScoreSchema.parse(output)
  })
}
