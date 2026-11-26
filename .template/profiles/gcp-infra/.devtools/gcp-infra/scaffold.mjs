const DEFAULTS = { environments: ['development', 'production'] }

export const deployEnvsOf = (makefile) =>
  makefile
    .match(/^DEPLOY_ENVS\s*[:?]?=([^#\n]*)/m)?.[1]
    .trim()
    .split(/\s+/)
    .filter(Boolean) ?? DEFAULTS.environments

export const tfvars = (slug, extra = {}) =>
  `${JSON.stringify(
    {
      project: slug,
      region: 'us-central1',
      service: slug,
      github_repository: `studiobimo/${slug}`,
      billing_account: '000000-000000-000000',
      monthly_budget: 25,
      ...extra
    },
    null,
    2
  )}\n`

const environmentList = (deployEnvs, quote) =>
  deployEnvs.map((name) => `${quote}${name}${quote}`).join(', ')

const tfVersions = `terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  backend "gcs" {
    bucket = "\${var.project}-tofu-state"
    prefix = "tofu"
  }
}

provider "google" {
  project = var.project
  region  = var.region

  billing_project       = var.project
  user_project_override = true
}
`

const tfVariables = `variable "project" {
  description = "The GCP project ID. One project per app: the account names below are fixed."
  type        = string
}

variable "region" {
  description = "The region the services, and the images they run, live in."
  type        = string
}

variable "service" {
  description = "The Cloud Run service's name, before -<environment>."
  type        = string
}

variable "github_repository" {
  description = "owner/name of the only repository whose workflows may deploy."
  type        = string
}

variable "billing_account" {
  description = "The billing account the project is on, XXXXXX-XXXXXX-XXXXXX, for its budget."
  type        = string
}

variable "monthly_budget" {
  description = "What the project should cost a month, in the billing account's currency."
  type        = number
}
`

const tfMain = (deployEnvs) => `locals {
  environments = toset([${environmentList(deployEnvs, '"')}])
}

data "google_project" "this" {}

resource "google_project_service" "api" {
  for_each = toset([
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
    "telemetry.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "source" {
  repository_id = "cloud-run-source-deploy"
  location      = var.region
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "2592000s"
    }
  }

  depends_on = [google_project_service.api]
}
`

const tfRuntime = (services) => `locals {
  runtime_services = toset([${environmentList(services, '"')}])
  runtime_accounts = {
    for pair in setproduct(local.runtime_services, local.environments) :
    "\${pair[0]}-\${pair[1]}" => { service = pair[0], environment = pair[1] }
  }
}

resource "google_service_account" "runtime" {
  for_each     = local.runtime_accounts
  account_id   = each.key
  display_name = "Cloud Run: \${var.service} \${each.value.service} (\${each.value.environment})"
  depends_on   = [google_project_service.api]
}

resource "google_project_iam_member" "runtime_telemetry" {
  for_each = {
    for pair in setproduct(keys(local.runtime_accounts), [
      "roles/cloudtrace.agent",
      "roles/monitoring.metricWriter",
      "roles/telemetry.metricsWriter",
      "roles/telemetry.tracesWriter",
    ]) : "\${pair[0]} \${pair[1]}" => { account = pair[0], role = pair[1] }
  }
  project    = var.project
  role       = each.value.role
  member     = google_service_account.runtime[each.value.account].member
  depends_on = [google_project_service.api]
}
`

const tfBudget = `resource "google_billing_budget" "project" {
  billing_account = var.billing_account
  display_name    = var.service

  budget_filter {
    projects = ["projects/\${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      units = tostring(var.monthly_budget)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  depends_on = [google_project_service.api]
}
`

const tfDeploy = (deployEnvs) => `resource "google_service_account" "builder" {
  account_id   = "builder"
  display_name = "Cloud Build: images for Cloud Run"
  depends_on   = [google_project_service.api]
}

resource "google_project_iam_member" "builder" {
  project = var.project
  role    = "roles/run.builder"
  member  = google_service_account.builder.member
}

resource "google_service_account" "deployer" {
  account_id   = "deployer"
  display_name = "GitHub Actions: deploys \${var.service}"
  depends_on   = [google_project_service.api]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(["roles/run.sourceDeveloper", "roles/serviceusage.serviceUsageConsumer"])
  project  = var.project
  role     = each.key
  member   = google_service_account.deployer.member
}

resource "google_service_account_iam_member" "deployer_acts_as" {
  for_each = merge(
    { for key, account in google_service_account.runtime : key => account.name },
    { builder = google_service_account.builder.name },
  )
  service_account_id = each.value
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deployer.member
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.api]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions"

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.environment" = "assertion.environment"
  }
  attribute_condition = "assertion.repository == '\${var.github_repository}' && assertion.environment in [${environmentList(deployEnvs, "'")}]"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_deploys" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/\${google_iam_workload_identity_pool.github.name}/attribute.repository/\${var.github_repository}"
}
`

const tfOutputs = `output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "deployer" {
  value = google_service_account.deployer.email
}
`

export const INFRA = {
  next: [
    'edit infra/project.auto.tfvars.json   # the GCP project, region, repository, billing account, budget',
    'make -C .devtools infra-bootstrap     # once: the bucket for OpenTofu state',
    'make -C .devtools infra-apply         # the accounts, Workload Identity, the project APIs',
    'make -C .devtools infra-github        # the repository variables deploy.yml signs in with'
  ]
}

export const infraFiles = ({ slug, deployEnvs, runtimeServices = ['app'] }, extraVars = {}) => ({
  'infra/project.auto.tfvars.json': tfvars(slug, extraVars),
  'infra/versions.tf': tfVersions,
  'infra/variables.tf': tfVariables,
  'infra/main.tf': tfMain(deployEnvs),
  'infra/runtime.tf': tfRuntime(runtimeServices),
  'infra/budget.tf': tfBudget,
  'infra/deploy.tf': tfDeploy(deployEnvs),
  'infra/outputs.tf': tfOutputs
})
