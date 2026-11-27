<!-- markdownlint-disable-file MD041 -- only the block is synced, into a full AGENTS.md -->
<!-- >>> template:gcp-infra -->
## Infrastructure: Google Cloud

The `gcp-infra` profile keeps this section, `.devtools/gcp-infra.mk` and
`.devtools/gcp-infra/` in step with the template. `infra/` is the project's:
`make -C .devtools infra-gen` writes a first version where there is none.

- **Infrastructure is OpenTofu, in `infra/`.** One GCP project per app, named in
  `infra/project.auto.tfvars.json` with the region and service name, which make reads too.
  Environments are `development` and `production`, or one per entry of `DEPLOY_ENVS` in
  `.devtools/Makefile` when it was set before `infra/` was written (`DEPLOY_ENVS := production`
  for a project with no development or `develop`). The state is in a GCS bucket that
  `make -C .devtools infra-bootstrap` creates once; `infra-plan` and `infra-apply` do the rest.
  Commit `infra/.terraform.lock.hcl`, which pins the provider; bump it by hand with
  `tofu init -upgrade`, a week after its release.
- **What it sets up.** The APIs for Cloud Run, Artifact Registry, Secret Manager, Pub/Sub,
  Vertex AI, Telemetry, Cloud Trace, Monitoring and Logging; the Artifact Registry
  repository; a runtime account per service and environment (`<service>-<environment>`, services listed in
  `local.runtime_services` in `infra/runtime.tf`, `app` unless a profile says otherwise); the `builder` and
  `deployer` accounts; and a budget on the billing account that mails its admins as the month
  nears `monthly_budget`. It warns, nothing caps it. Applying it takes Billing Account Costs
  Manager, or Administrator, on that account.
- **Runtime accounts** can write traces and metrics and nothing else. Grant one what its
  service uses, a secret, a topic or a model, in `infra/`; one account per service keeps a
  public service from holding what a private one needs. Environment variables and secrets go
  on the service there too, never in the image.
- **Deploys sign in with Workload Identity Federation**, no key stored anywhere, and only
  jobs in a GitHub environment named after one of the environments can.
  `make -C .devtools infra-github` sets the two repository variables the deploy workflow
  reads, `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_SERVICE_ACCOUNT`.
- **Why the HCL has no comments.** `cloudresourcemanager` and `serviceusage` are enabled
  first because the other APIs cannot be enabled without them, and the accounts wait for the
  APIs. The provider sets `billing_project` and `user_project_override` because the budget
  API bills its quota to a project and a person's credentials have none. The state bucket's
  name follows `var.project`, since OpenTofu evaluates that variable before anything else.
  Artifact Registry's repository is made here so old images are cleaned up, not by the first
  deploy. `builder` builds images instead of the default compute account; `deployer` uploads
  the source, starts a build as `builder` and rolls out as a runtime account. Workload
  Identity admits only a job in `github_repository` that names a GitHub environment, so the
  environments' rules decide who deploys. The budget mails at half, nine tenths and all of
  `monthly_budget` and when it is forecast to pass it; it stops nothing.
<!-- <<< template:gcp-infra -->
