export const PHOENIX = {
  dirs: {
    templates: '.devtools/phoenix/templates',
    patches: '.devtools/phoenix/patches',
    contracts: 'packages/contracts',
    eval: 'services/eval'
  },
  templateSuffix: '.tpl',
  scopeToken: '@scope/',
  evalService: 'eval',
  sampleFiles: ['src/handler.ts', 'src/handler.test.ts', 'src/index.ts'],
  needs: {
    cloudsql: 'infra/cloudsql.tf',
    adk: '.devtools/adk/gen.mjs',
    worker: 'services/worker/src/app.ts'
  },
  contentAttributes: [
    'gen_ai.input.messages',
    'gen_ai.output.messages',
    'gen_ai.system_instructions',
    'gen_ai.tool.call.arguments',
    'gen_ai.tool.call.result',
    'gen_ai.tool.definitions',
    'gcp.vertex.agent.data'
  ],
  tokens: {
    project: '__PROJECT__',
    strip: '__STRIP__'
  },
  stripIndent: '          ',
  packages: {
    eval: {
      main: 'dist/index.js',
      dependencies: [
        '@scope/contracts@workspace:*',
        '@scope/platform@workspace:*',
        '@scope/worker@workspace:*',
        '@google/adk'
      ],
      devDependencies: ['@opentelemetry/sdk-trace-base']
    },
    worker: { dependencies: ['@opentelemetry/api'] }
  },
  edits: {
    'packages/contracts/src/index.ts': [
      {
        from: "export type { PushEnvelope } from './push.ts'\n",
        after:
          "export { runCompleted, runCompletedSchema, runScoreSchema } from './run-completed.ts'\nexport type { RunCompleted, RunScore } from './run-completed.ts'\n"
      }
    ],
    'services/worker/src/app.ts': [
      {
        from: '  onVerdict?: (event: PrEvent, verdict: TriageVerdict) => void\n',
        to: '  onVerdict?: (event: PrEvent, verdict: TriageVerdict) => Promise<void> | void\n'
      },
      { from: '        onVerdict?.(event, verdict)\n', to: '        await onVerdict?.(event, verdict)\n' },
      {
        from: "export { ScriptedLlm } from './scripted-llm.ts'\n",
        after:
          "export { judgeModelName, vertexModel } from './models.ts'\nexport { publishRunCompleted } from './run-completed.ts'\n"
      }
    ],
    'services/worker/src/index.ts': [
      {
        from: "import { serve, startTelemetry } from '@scope/platform'",
        to: "import { PubSubPublisher, serve, startTelemetry } from '@scope/platform'"
      },
      {
        from: "import { sessionService } from './sessions.ts'\n",
        after: "import { publishRunCompleted } from './run-completed.ts'\n"
      },
      {
        from: 'serve(createWorker({ judge: vertexModel(judgeModelName()), sessions }))',
        to: [
          'serve(',
          '  createWorker({',
          '    judge: vertexModel(judgeModelName()),',
          '    sessions,',
          '    onVerdict: publishRunCompleted(new PubSubPublisher(process.env.PUBSUB_TOPIC_SUFFIX))',
          '  })',
          ')'
        ].join('\n')
      }
    ],
    'infra/runtime.tf': [
      { from: '"ingress", "worker"]', to: '"ingress", "worker", "eval", "phoenix"]' }
    ],
    'infra/service.tf': [
      {
        from: '  adk_services = toset(["ingress", "worker"])\n',
        to: '  adk_services = toset(["ingress", "worker", "eval"])\n'
      },
      {
        from: '        name  = "OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT"\n        value = each.value.environment == "production" ? "false" : "true"\n',
        to: '        name  = "OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT"\n        value = "SPAN_ONLY"\n'
      },
      {
        from: '      dynamic "env" {\n        for_each = each.value.service == "ingress" ? {\n',
        before: 'service-eval-env.tf.tpl'
      },
      {
        from: '      args  = ["--config=/etc/otelcol/config.yaml"]\n',
        after: 'service-collector-env.tf.tpl'
      }
    ],
    'infra/collector.yaml': [
      { from: '\nexporters:\n', before: 'collector-processors.yaml.tpl' },
      { from: '\nservice:\n', before: 'collector-exporter.yaml.tpl' },
      {
        from: '    traces:\n      receivers: [otlp]\n      processors: [memory_limiter, resourcedetection/gcp, batch]\n      exporters: [otlphttp/gcp]\n',
        patch: 'collector-pipelines.yaml.tpl'
      }
    ],
    'packages/local/src/collector.test.ts': [
      {
        from: '  processors: Record<string, unknown>\n',
        to: '  processors: Record<string, { trace_statements?: Array<{ context: string; statements: string[] }> }>\n'
      },
      {
        from: '  exporters: Record<string, { endpoint?: string; auth?: { authenticator: string } }>\n',
        to: '  exporters: Record<\n    string,\n    { endpoint?: string; headers?: Record<string, string>; auth?: { authenticator: string } }\n  >\n'
      },
      { from: "  it('listens on the port", before: 'collector-tests.ts.tpl' }
    ]
  }
}

export const SAY = {
  missing: (path, hint) => `${path} is missing: ${hint}`,
  hints: {
    cloudsql: 'make -C .devtools cloudsql-gen first',
    adk: 'list the adk profile, sync and run make -C .devtools adk-gen first'
  },
  usage: 'usage: gen.mjs',
  next: [
    'make -C .devtools check            # the eval worker runs end to end against a fake Phoenix',
    'make -C .devtools infra-apply      # Phoenix on Cloud Run, its database, the eval service and its topic',
    'tofu -chdir=infra output phoenix   # the OAuth redirect URI to register, and the two secrets to fill',
    'set phoenix_admins in infra/project.auto.tfvars.json: the emails that may sign in with Google',
    'make -C .devtools adk-deploy ENV=development   # ships the eval service with the other two'
  ]
}
