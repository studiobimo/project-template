import { z } from 'zod'

import { defineTopic } from './topic.ts'

export const prEventSchema = z.object({
  source: z.enum(['github', 'slack']),
  deliveryId: z.string().min(1),
  repository: z.string().min(1),
  pullRequest: z.number().int().positive(),
  action: z.string().min(1),
  title: z.string().default(''),
  body: z.string().default(''),
  changedFiles: z.array(z.string()).default([])
})

export type PrEvent = z.output<typeof prEventSchema>

export const prEvent = defineTopic('pr-events', prEventSchema)

export const orderingKeyOf = ({
  repository,
  pullRequest
}: Pick<PrEvent, 'repository' | 'pullRequest'>) => `${repository}#${pullRequest}`

export const triageVerdictSchema = z.object({
  verdict: z.enum(['approve', 'review']),
  reason: z.string().min(1)
})

export type TriageVerdict = z.output<typeof triageVerdictSchema>

export const evalCaseSchema = z.object({
  name: z.string().min(1),
  event: prEventSchema,
  expect: triageVerdictSchema.pick({ verdict: true })
})

export const evalCasesSchema = z.array(evalCaseSchema)

export type EvalCase = z.output<typeof evalCaseSchema>
