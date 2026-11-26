export const TELEMETRY = {
  tracer: 'platform',
  attributes: {
    topic: 'messaging.destination.name',
    orderingKey: 'messaging.gcp_pubsub.message.ordering_key',
    messageId: 'messaging.message.id',
    system: 'messaging.system'
  },
  values: { system: 'gcp_pubsub' },
  spans: {
    publish: (topic: string) => `${topic} publish`,
    process: (topic: string) => `${topic} process`
  }
}

export const BUS = {
  maxAttempts: 5
}

export const HTTP = {
  defaultPort: 8080,
  limits: { bodyBytes: 1024 * 1024 },
  statuses: { tooLarge: 413, failed: 500 },
  messages: {
    listening: (port: number) => `listening on ${port}`,
    failed: 'unhandled error',
    flushFailed: 'telemetry flush failed'
  }
}
