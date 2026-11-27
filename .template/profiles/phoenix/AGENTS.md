<!-- markdownlint-disable-file MD041 -- only the block is synced, into a full AGENTS.md -->
<!-- >>> template:phoenix -->
## LLM observability: Arize Phoenix

The `phoenix` profile keeps this section, `.devtools/phoenix.mk` and `.devtools/phoenix/` in
step with the template, on top of `gcp-infra`, `typescript`, `cloudsql` and `adk`, listed in
that order before it; `include phoenix.mk` from `.devtools/Makefile` after `adk.mk`.
`make -C .devtools phoenix-gen` writes `infra/phoenix.tf`, `services/eval` and the
`run-completed` contract once, and patches the worker, `infra/service.tf` and
`infra/collector.yaml`; from then on they are the project's.

**Phoenix is licensed under the Elastic License 2.0: internal use only.** Run it for the
project's own traces; never offer it to others as a hosted or managed service.

- **Phoenix on Cloud Run**, `<service>-phoenix-<environment>`, from
  `docker.io/arizephoenix/phoenix:<version>@sha256:<digest>` (`phoenix_image`). Nothing watches
  the pin: bump the tag and the index digest together by hand. It has its own database and
  user on the `cloudsql` instance, reached through Cloud Run's Cloud SQL socket; the connection
  string, with its generated password, is a Secret Manager secret.
  Phoenix and the eval worker run as their own runtime accounts, `phoenix-<environment>` and
  `eval-<environment>`, which `phoenix-gen` adds to `local.runtime_services`.
- **Sign-in is Google, through Phoenix's own OAuth2, not IAP.** IAP replaces the caller's
  identity and would lock out the collector and the eval worker, which call with an API key.
  Basic auth is off; `PHOENIX_ENABLE_AUTH` is on. `phoenix_admins` lists the emails that
  may sign in; nobody else can sign up, and they add the rest in Phoenix. Create a Google
  OAuth client of type web, register `tofu -chdir=infra output phoenix`'s
  `oauth_redirect_uri`, and add its id and secret as new versions of the two `google-client-*`
  secrets it lists.
- **The API key** is `PHOENIX_ADMIN_SECRET`, generated, in Secret Manager. The collector and
  the eval worker send it as `Authorization: Bearer`.
- **Telemetry is off** (`PHOENIX_TELEMETRY_ENABLED=false`). Traces are kept
  `phoenix_retention_days` (default 30; 0 keeps them for ever).
- **Traces reach Phoenix through the collector sidecar**, over OTLP/HTTP, in a
  `traces/phoenix` pipeline of their own. ADK 2.5 sets the current `gen_ai.*` attributes
  (`gen_ai.input.messages`, `gen_ai.output.messages`, usage, request model), which Phoenix
  from 15.10 converts to OpenInference when it ingests them, so the services add no
  instrumentation of their own.
- **Prompts and responses go to Phoenix only.** The services capture them
  (`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=SPAN_ONLY`, in every environment: ADK
  ignores `true` for spans and sends it to a log event), and the `traces` pipeline to Cloud
  Trace deletes `gen_ai.input.messages`, `gen_ai.output.messages`, the system instructions,
  tool arguments, results and definitions with a `transform/attributes` processor, on spans and
  span events. The collector config test fails if one is missing. A new content attribute
  needs a line there, in that processor and in the test.
- **The eval worker** (`services/eval`, a third adk service on the same image and collector)
  takes `run-completed` from Pub/Sub. The worker publishes it at the end of a run with the
  event, the verdict, and the trace and span id of its `pr-events process` span. The eval worker
  scores it with an ADK judge on Vertex AI and posts `verdict-quality` to
  `POST /v1/span_annotations?sync=true` on that span. An answer that is not JSON (a login
  page) or a span Phoenix has not ingested yet is a 500, so Pub/Sub retries it with backoff,
  five times, then dead-letters it.
- **Tests** run the whole path in process: a push, the worker, `run-completed`, a scripted
  judge, and an annotation posted to a fake Phoenix server whose request they check.
<!-- <<< template:phoenix -->
