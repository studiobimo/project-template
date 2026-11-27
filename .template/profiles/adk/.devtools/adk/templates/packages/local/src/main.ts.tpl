import { BatchSpanProcessor, ConsoleSpanExporter } from '@opentelemetry/sdk-trace-base'
import { serve, startTelemetry } from '@scope/platform'
import { ScriptedLlm } from '@scope/worker'

import { startLocal } from './local.ts'
import { LOCAL } from './strings.ts'

startTelemetry('local', [
  { spanProcessors: [new BatchSpanProcessor(new ConsoleSpanExporter())] }
])

const { ingress, bus } = startLocal(
  new ScriptedLlm(() => JSON.stringify(LOCAL.verdict)),
  {
    githubSecret: process.env[LOCAL.env.githubSecret] ?? LOCAL.secrets.github,
    slackSecret: process.env[LOCAL.env.slackSecret] ?? LOCAL.secrets.slack
  }
)

serve(async (request) => {
  const reply = await ingress(request)
  await bus.idle()
  console.log(LOCAL.messages.delivered(bus.deliveries.map(({ reply }) => reply.body)))
  return reply
})
