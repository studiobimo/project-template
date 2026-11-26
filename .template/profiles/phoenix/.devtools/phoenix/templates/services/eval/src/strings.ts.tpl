export const EVAL = {
  app: 'adk-eval',
  user: 'eval',
  paths: { push: '/' },
  env: { phoenixUrl: 'PHOENIX_URL', phoenixKey: 'PHOENIX_API_KEY' },
  phoenix: {
    annotationsPath: '/v1/span_annotations?sync=true',
    annotatorKind: 'LLM',
    annotationName: 'verdict-quality',
    json: 'application/json'
  },
  workflows: { score: 'score', prepare: 'prepare', judge: 'run-judge' },
  spans: {
    workflow: (name: string) => `eval ${name}`,
    step: (name: string) => `step ${name}`
  },
  instructions: {
    judge: [
      'You grade a pull request triage that already ran. You get the pull request and the verdict a first judge gave.',
      'Answer good with a score near 1 when the verdict follows from the facts, for example approve for a change to documentation only.',
      'Answer poor with a score near 0 when it does not, for example approve for a change to code that guards access.',
      'Give one short sentence as the explanation.'
    ].join(' ')
  },
  messages: {
    notFound: 'not found',
    badPush: 'bad push body',
    noScore: 'the workflow produced no score',
    missing: (name: string) => `${name} is not set`,
    phoenixRefused: (status: number, type: string) =>
      `phoenix answered ${status} with ${type || 'no content type'}: not an annotation, check the url and the key`
  }
}
