import { z } from 'zod'

export const pushEnvelopeSchema = z.object({
  message: z.object({
    data: z.string(),
    messageId: z.string(),
    orderingKey: z.string().optional(),
    attributes: z.record(z.string(), z.string()).default({})
  }),
  subscription: z.string()
})

export type PushEnvelope = z.output<typeof pushEnvelopeSchema>

export const parsePushEnvelope = (body: string): PushEnvelope =>
  pushEnvelopeSchema.parse(JSON.parse(body))
