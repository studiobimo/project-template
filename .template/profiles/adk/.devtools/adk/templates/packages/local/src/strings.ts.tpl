export const LOCAL = {
  env: { githubSecret: 'GITHUB_WEBHOOK_SECRET', slackSecret: 'SLACK_SIGNING_SECRET' },
  secrets: { github: 'local-github', slack: 'local-slack' },
  verdict: { verdict: 'review', reason: 'the local judge always asks for a review' },
  files: { collector: '../../infra/collector.yaml' },
  messages: {
    delivered: (bodies: string[]) => `worker replies so far: ${bodies.join(' ')}`
  }
}
