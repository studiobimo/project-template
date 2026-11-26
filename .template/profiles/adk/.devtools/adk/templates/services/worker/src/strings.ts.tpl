export const WORKER = {
  app: 'adk-worker',
  user: 'push',
  paths: { push: '/' },
  models: {
    judge: 'gemini-2.5-flash',
    claudePrefix: 'claude',
    defaultLocation: 'us-central1',
    defaultClaudeLocation: 'us-east5',
    maxTokens: 1024
  },
  env: {
    judgeModel: 'JUDGE_MODEL',
    project: 'GOOGLE_CLOUD_PROJECT',
    location: 'GOOGLE_CLOUD_LOCATION',
    claudeLocation: 'CLAUDE_LOCATION'
  },
  workflows: { triage: 'triage', facts: 'facts', judge: 'judge' },
  facts: { bodyLimit: 2000, docsExtensions: ['.md', '.mdx', '.txt'] },
  spans: {
    workflow: (name: string) => `workflow ${name}`,
    step: (name: string) => `step ${name}`
  },
  attributes: { repository: 'pr.repository', pullRequest: 'pr.number', verdict: 'triage.verdict' },
  files: { graphs: 'graphs', evalCases: 'evals/cases.json' },
  instructions: {
    judge: [
      'You judge whether a pull request needs a human review. Code has already gathered the facts.',
      'Answer approve only for a change that is clearly low risk, for example documentation only.',
      'Answer review for anything else, and give one short sentence as the reason.'
    ].join(' ')
  },
  messages: {
    notFound: 'not found',
    badPush: 'bad push body',
    noVerdict: 'the workflow produced no verdict',
    claudeNoText: 'the model returned no text',
    claudeLive: 'live connections are not supported for Claude on Vertex AI',
    claudeSchema: (schema: string) => `Reply with only JSON that matches this schema: ${schema}`,
    graphWritten: (path: string) => `wrote ${path}`,
    graphStale: (path: string) => `${path} is out of date: run make -C .devtools adk-graphs`,
    evalPassed: (name: string) => `pass ${name}`,
    evalFailed: (name: string, want: string, got: string) => `FAIL ${name}: want ${want}, got ${got}`,
    evalSummary: (passed: number, total: number) => `${passed}/${total} passed`
  }
}
