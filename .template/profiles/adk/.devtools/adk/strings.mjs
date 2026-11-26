export const ADK = {
  dirs: {
    templates: '.devtools/adk/templates',
    contracts: 'packages/contracts',
    infra: 'infra'
  },
  files: { runtime: 'infra/runtime.tf' },
  runtimeServices: /runtime_services = toset\(\[([^\]]*)\]\)/,
  templateSuffix: '.tpl',
  scopeToken: '@scope/',
  libraries: ['platform', 'local'],
  services: ['ingress', 'worker'],
  sampleFiles: ['src/handler.ts', 'src/handler.test.ts'],
  contractExports: [
    "export { evalCaseSchema, evalCasesSchema, orderingKeyOf, prEvent, prEventSchema, triageVerdictSchema } from './pr-event.ts'",
    "export type { EvalCase, PrEvent, TriageVerdict } from './pr-event.ts'",
    "export { parsePushEnvelope, pushEnvelopeSchema } from './push.ts'",
    "export type { PushEnvelope } from './push.ts'",
    "export { githubPullRequestSchema, pullRequestReferenceSchema, slackCommandSchema, slackUrlVerificationSchema } from './webhooks.ts'"
  ],
  knipEntries: {
    'services/worker': ['src/graphs-main.ts', 'src/eval-main.ts'],
    'packages/local': ['src/main.ts']
  },
  allowBuilds: ['@google/genai', 'cpu-features', 'protobufjs', 'ssh2'],
  packages: {
    platform: {
      dependencies: [
        '@scope/contracts@workspace:*',
        '@google/adk',
        '@google-cloud/pubsub',
        '@opentelemetry/api',
        '@opentelemetry/core'
      ]
    },
    ingress: {
      exports: './dist/app.js',
      dependencies: ['@scope/platform@workspace:*']
    },
    worker: {
      exports: './dist/app.js',
      dependencies: [
        '@scope/platform@workspace:*',
        '@google/adk',
        '@anthropic-ai/vertex-sdk'
      ],
      scripts: {
        graphs: 'node dist/graphs-main.js',
        'graphs:check': 'node dist/graphs-main.js --check',
        eval: 'node dist/eval-main.js'
      }
    },
    local: {
      exports: './dist/local.js',
      dependencies: [
        '@scope/contracts@workspace:*',
        '@scope/ingress@workspace:*',
        '@scope/platform@workspace:*',
        '@scope/worker@workspace:*',
        '@opentelemetry/sdk-trace-base'
      ],
      devDependencies: ['yaml'],
      scripts: { start: 'node dist/main.js' }
    }
  }
}

export const SAY = {
  noWorkspace: (gen) => `no ${ADK.dirs.contracts}: run ${gen} workspace first`,
  runtimeServices: (path) => `${path} has no local.runtime_services list for the adk services`,
  usage: (kinds) => `usage: gen.mjs <${kinds.join('|')}>`,
  next: [
    'edit infra/project.auto.tfvars.json   # the GCP project, region, repository, billing account, budget',
    'make -C .devtools check               # offline: unit tests, the traced ingress-to-worker run, graphs',
    'make -C .devtools adk-dev             # ingress, bus and worker in one process, scripted judge',
    'make -C .devtools infra-bootstrap     # once: the bucket for OpenTofu state',
    'make -C .devtools infra-apply         # topics, subscriptions, secrets and the Cloud Run services',
    'make -C .devtools adk-deploy ENV=development'
  ]
}
