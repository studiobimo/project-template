import { z } from 'zod'

export const githubPullRequestSchema = z.object({
  action: z.string().min(1),
  number: z.number().int().positive(),
  pull_request: z.object({
    title: z.string(),
    body: z.string().nullable()
  }),
  repository: z.object({ full_name: z.string().min(1) })
})

export const slackUrlVerificationSchema = z.object({
  type: z.literal('url_verification'),
  challenge: z.string()
})

export const slackCommandSchema = z.object({
  trigger_id: z.string().min(1),
  text: z.string()
})

export const pullRequestReferenceSchema = z
  .string()
  .regex(/^[\w.-]+\/[\w.-]+#\d+$/)
  .transform((reference) => {
    const [repository = '', number = ''] = reference.split('#')
    return { repository, pullRequest: Number(number) }
  })
