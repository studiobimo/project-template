export const INGRESS = {
  paths: { github: '/github', slack: '/slack' },
  headers: {
    githubSignature: 'x-hub-signature-256',
    githubEvent: 'x-github-event',
    githubDelivery: 'x-github-delivery',
    slackSignature: 'x-slack-signature',
    slackTimestamp: 'x-slack-request-timestamp'
  },
  limits: {
    slackSkewSeconds: 300,
    githubAckMs: 8000,
    slackAckMs: 2500
  },
  signatures: { githubPrefix: 'sha256=', slackVersion: 'v0' },
  events: { githubPullRequest: 'pull_request', githubPing: 'ping' },
  spans: { request: (path: string) => `ingress ${path}` },
  env: {
    githubSecret: 'GITHUB_WEBHOOK_SECRET',
    slackSecret: 'SLACK_SIGNING_SECRET',
    topicSuffix: 'PUBSUB_TOPIC_SUFFIX'
  },
  messages: {
    queued: 'queued',
    ignored: 'ignored',
    pong: 'pong',
    unauthorized: 'bad signature',
    notFound: 'not found',
    badRequest: 'bad request',
    unavailable: 'could not queue the event',
    usage: 'usage: /review owner/repo#123',
    missingSecret: (name: string) => `${name} is not set`
  }
}
