import { PubSubPublisher, serve, startTelemetry } from '@scope/platform'

import { createIngress } from './app.ts'
import { INGRESS } from './strings.ts'

const required = (name: string): string => {
  const value = process.env[name]
  if (!value) throw new Error(INGRESS.messages.missingSecret(name))
  return value
}

startTelemetry('ingress')

serve(
  createIngress({
    publisher: new PubSubPublisher(process.env[INGRESS.env.topicSuffix]),
    githubSecret: required(INGRESS.env.githubSecret),
    slackSecret: required(INGRESS.env.slackSecret)
  })
)
