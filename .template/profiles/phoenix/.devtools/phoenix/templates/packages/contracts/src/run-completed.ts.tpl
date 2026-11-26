import { z } from 'zod'

import { prEventSchema, triageVerdictSchema } from './pr-event.ts'
import { defineTopic } from './topic.ts'

export const runCompletedSchema = z.object({
  event: prEventSchema,
  verdict: triageVerdictSchema,
  traceId: z.string().regex(/^[0-9a-f]{32}$/),
  spanId: z.string().regex(/^[0-9a-f]{16}$/)
})

export type RunCompleted = z.output<typeof runCompletedSchema>

export const runCompleted = defineTopic('run-completed', runCompletedSchema)

export const runScoreSchema = z.object({
  label: z.enum(['good', 'poor']),
  score: z.number().min(0).max(1),
  explanation: z.string().min(1)
})

export type RunScore = z.output<typeof runScoreSchema>
