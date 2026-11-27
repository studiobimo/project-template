import {
  FunctionNode,
  InMemorySessionService,
  LlmAgent,
  Runner,
  START,
  Workflow,
  type BaseLlm,
  type BaseSessionService
} from '@google/adk'
import {
  prEventSchema,
  triageVerdictSchema,
  type PrEvent,
  type TriageVerdict
} from '@scope/contracts'
import { inSpan } from '@scope/platform'

import { WORKER } from './strings.ts'

export type Judge = BaseLlm | string

export const gatherFacts = (event: PrEvent) => ({
  repository: event.repository,
  pullRequest: event.pullRequest,
  title: event.title,
  body: event.body.slice(0, WORKER.facts.bodyLimit),
  changedFiles: event.changedFiles.length,
  docsOnly:
    event.changedFiles.length > 0 &&
    event.changedFiles.every((file) =>
      WORKER.facts.docsExtensions.some((extension) => file.endsWith(extension))
    )
})

const facts = new FunctionNode(WORKER.workflows.facts, (_context, input: string) =>
  inSpan(WORKER.spans.step(WORKER.workflows.facts), () =>
    gatherFacts(prEventSchema.parse(JSON.parse(input)))
  )
)

export function buildTriage(judge: Judge): Workflow {
  const verdict = new LlmAgent({
    name: WORKER.workflows.judge,
    model: judge,
    instruction: WORKER.instructions.judge,
    outputSchema: triageVerdictSchema,
    includeContents: 'none'
  })
  return new Workflow({
    name: WORKER.workflows.triage,
    edges: [[START, facts, verdict]]
  })
}

export async function runTriage(
  workflow: Workflow,
  event: PrEvent,
  sessionService: BaseSessionService = new InMemorySessionService()
): Promise<TriageVerdict> {
  return inSpan(WORKER.spans.workflow(workflow.name), async (span) => {
    span.setAttributes({
      [WORKER.attributes.repository]: event.repository,
      [WORKER.attributes.pullRequest]: event.pullRequest
    })
    const runner = new Runner({
      agent: workflow,
      appName: WORKER.app,
      sessionService,
      autoCreateSession: true
    })
    let output: unknown
    for await (const step of runner.runAsync({
      userId: WORKER.user,
      sessionId: event.deliveryId,
      newMessage: { role: 'user', parts: [{ text: JSON.stringify(event) }] }
    })) {
      if (step.author === WORKER.workflows.judge && step.output !== undefined) output = step.output
    }
    if (output === undefined) throw new Error(WORKER.messages.noVerdict)
    const verdict = triageVerdictSchema.parse(output)
    span.setAttribute(WORKER.attributes.verdict, verdict.verdict)
    return verdict
  })
}
