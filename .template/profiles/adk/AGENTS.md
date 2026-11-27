<!-- markdownlint-disable-file MD041 -- only the block is synced, into a full AGENTS.md -->
<!-- >>> template:adk -->
## Agents: Google ADK on Cloud Run, driven by Pub/Sub

The `adk` profile keeps this section, `.devtools/adk.mk` and `.devtools/adk/` in step with the
template. `make -C .devtools adk-gen` writes the first version of `packages/contracts`' topics,
`packages/platform`, `packages/local`, `services/ingress`, `services/worker` and the agent
half of `infra/`; from then on they are the project's.

### Design: code does the work, models only judge

- **A workflow is a graph of code steps with a few judge steps.** ADK 2.x `Workflow` (package
  `@google/adk`, still marked experimental). A code step is a `FunctionNode`: plain,
  deterministic, tested without a model. A judge step is an `LlmAgent` with an `outputSchema`,
  which takes a zod schema from `packages/contracts` and validates what the model answers.
  Anything a program can decide stays out of the prompt.
- **Every model runs on Vertex AI** with the runtime account's credentials (ADC): no API keys,
  anywhere. `vertexModel(name)` returns Gemini for `gemini-*` and `VertexClaude` for `claude-*`
  (Claude through Model Garden; ADK has no Claude class of its own). Change the judge with
  `JUDGE_MODEL`.
- **Tests never call a model.** `ScriptedLlm` answers from a function. `make -C .devtools
  adk-eval` scores `services/worker/evals/cases.json` against the real judge on Vertex AI.
- **Graphs are data.** `make -C .devtools adk-graphs` writes `graphs/<workflow>.json` (React Flow
  nodes and edges); `make ci` fails when they are stale. Register a workflow in
  `services/worker/src/workflows.ts` to have it exported.
- **Sessions** come from `sessionService()` in `services/worker/src/sessions.ts`: in memory
  until the `cloudsql` profile moves them to Postgres (`cloudsql-adk-gen`), which a workflow
  that pauses needs. Each run's session is named after the delivery.

### Messages

- **ingress** verifies GitHub (`X-Hub-Signature-256`) and Slack (v0 signing secret, five minutes
  of timestamp skew), acks within their limits (8 s and 2.5 s, else 503 so they retry), and
  publishes `pr-events` with the pull request (`owner/repo#number`) as ordering key.
- **worker** takes Pub/Sub pushes, decodes through the topic's zod schema, runs the workflow and
  answers 200. Any other status makes Pub/Sub retry with backoff, five times, then dead-letter.
  A message is nacked rather than dropped: look in `pr-events-dead-letter-<environment>`.
- **`serve()`** caps a request body at 1 MiB (413 past it, nothing more buffered), and flushes
  telemetry before it answers: both services run with `cpu_idle`, so a span still queued when
  the response goes out may never be exported.
- **One schema per message** stays in `packages/contracts` (see the typescript profile). A new
  topic is a `defineTopic` there, a topic and subscription in `infra/pubsub.tf`, and a route.

### Observability

- **One trace from the webhook to the last step.** `publishTopic` injects `traceparent` into
  the Pub/Sub message attributes, `consumeTopic` extracts it, so the ingress request, the
  publish, the push, the workflow and ADK's own `invoke_agent` and model spans share a trace id.
  Wrap your own code steps in `inSpan(name, work)`; never start a trace by hand.
- **Export** is OTLP to an OpenTelemetry Collector sidecar (`infra/collector.yaml`, kept in
  Secret Manager) that forwards traces and metrics to `telemetry.googleapis.com` with
  `googleclientauth`, so Cloud Trace and Monitoring show them. The services only know
  `OTEL_EXPORTER_OTLP_ENDPOINT`.
- **Prompt and response content is not captured in production**
  (`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` and
  `ADK_CAPTURE_MESSAGE_CONTENT_IN_SPANS` are `false` there, `true` in development). Never set
  them to true on a production service.

### Infrastructure

- **One runtime account per service and environment** (`ingress-<environment>`,
  `worker-<environment>`, from `local.runtime_services` in `infra/runtime.tf`). The public
  ingress gets the accessor role on its two webhook secrets and publisher on its topic, and
  nothing else; the worker gets `roles/aiplatform.user`. Both read the collector's config.
  `adk-gen` adds both to that list, keeping the services already there.
- **Ack deadline and request timeout are one value**, `local.request_timeout_seconds` in
  `infra/service.tf`: the push subscription must wait at least as long as the worker may run.
- **Claude has its own location**, `claude_location` (default `us-east5`; `europe-west1` or
  `global` also serve it), read by the worker as `CLAUDE_LOCATION`. Gemini keeps `var.region`.
- **Secrets.** Each webhook secret starts as a random placeholder version, so the services can
  start before the real value is known; no GitHub or Slack signature matches it. Add the real
  one with `printf '%s' "$SECRET" | gcloud secrets versions add <secret-id> --data-file=-`, and
  the next deploy of the ingress picks it up. A secret on the worker (`adk_worker_secret_env`)
  names the secret and its version, so the service waits for both and for the accessor binding.
- **Why the HCL has no comments.** Models go through Vertex AI with the runtime account's
  credentials. The ingress is public (its signature checks are the lock); the worker takes
  Pub/Sub pushes only, as `pubsub-invoker`. The push subscription is ordered per pull request,
  retries with backoff five times, then dead-letters; the dead-letter topic's pull
  subscription holds messages for a week. The collector is a sidecar whose config sits in
  Secret Manager and is mounted into it.

### Commands

```sh
make -C .devtools adk-dev      # ingress, bus and worker in one process, scripted judge
make -C .devtools adk-eval     # the eval cases against the real judge (Vertex AI)
make -C .devtools adk-graphs   # graphs/<workflow>.json
make -C .devtools adk-deploy ENV=development   # images, push, roll out both services
```
<!-- <<< template:adk -->
