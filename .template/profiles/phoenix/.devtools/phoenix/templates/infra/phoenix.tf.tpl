variable "phoenix_image" {
  description = "The Phoenix image, pinned by version and digest. Bump both by hand: nothing watches it."
  type        = string
  default     = "docker.io/arizephoenix/phoenix:22.1.0@sha256:431274c2e151c0341a3bb44e2c7381a9c2115f744bd57fd9b2ecee0c58299eab"
}

variable "phoenix_retention_days" {
  description = "How long Phoenix keeps traces, in days. 0 keeps them for ever."
  type        = number
  default     = 30
}

variable "phoenix_admins" {
  description = "Emails that may sign in to Phoenix with Google, as administrators. Nobody else can sign up; they add the rest in Phoenix."
  type        = list(string)
  default     = []
}

locals {
  phoenix_topic        = "run-completed"
  phoenix_generated    = toset(["database-url", "secret", "admin-secret"])
  phoenix_operator     = toset(["google-client-id", "google-client-secret"])
  phoenix_google_oidc  = "https://accounts.google.com/.well-known/openid-configuration"
  phoenix_admin_emails = join(";", [for email in var.phoenix_admins : "${split("@", email)[0]}=${email}"])

  phoenix_urls = {
    for env in local.environments :
    env => "https://${var.service}-phoenix-${env}-${data.google_project.this.number}.${var.region}.run.app"
  }

  phoenix_secret_ids = {
    for pair in setproduct(local.environments, setunion(local.phoenix_generated, local.phoenix_operator)) :
    "${pair[1]}-${pair[0]}" => { environment = pair[0], name = pair[1] }
  }

  phoenix_generated_values = {
    for env in local.environments : env => {
      "database-url" = "postgresql://${google_sql_user.phoenix[env].name}:${random_password.phoenix_database[env].result}@/${google_sql_database.phoenix[env].name}?host=/cloudsql/${google_sql_database_instance.main[env].connection_name}"
      "secret"       = random_password.phoenix_secret[env].result
      "admin-secret" = random_password.phoenix_admin_secret[env].result
    }
  }

  phoenix_secret_name = {
    for env in local.environments : env => {
      for name in setunion(local.phoenix_generated, local.phoenix_operator) :
      name => google_secret_manager_secret.phoenix["${name}-${env}"].secret_id
    }
  }

  phoenix_env = {
    for env in local.environments : env => {
      PHOENIX_ENABLE_AUTH                   = "true"
      PHOENIX_DISABLE_BASIC_AUTH            = "true"
      PHOENIX_USE_SECURE_COOKIES            = "true"
      PHOENIX_ROOT_URL                      = local.phoenix_urls[env]
      PHOENIX_TELEMETRY_ENABLED             = "false"
      PHOENIX_DEFAULT_RETENTION_POLICY_DAYS = tostring(var.phoenix_retention_days)
      PHOENIX_ADMINS                        = local.phoenix_admin_emails
      PHOENIX_OAUTH2_GOOGLE_DISPLAY_NAME    = "Google"
      PHOENIX_OAUTH2_GOOGLE_OIDC_CONFIG_URL = local.phoenix_google_oidc
      PHOENIX_OAUTH2_GOOGLE_ALLOW_SIGN_UP   = "false"
    }
  }

  phoenix_secret_env = {
    for env in local.environments : env => {
      PHOENIX_SQL_DATABASE_URL            = local.phoenix_secret_name[env]["database-url"]
      PHOENIX_SECRET                      = local.phoenix_secret_name[env]["secret"]
      PHOENIX_ADMIN_SECRET                = local.phoenix_secret_name[env]["admin-secret"]
      PHOENIX_OAUTH2_GOOGLE_CLIENT_ID     = local.phoenix_secret_name[env]["google-client-id"]
      PHOENIX_OAUTH2_GOOGLE_CLIENT_SECRET = local.phoenix_secret_name[env]["google-client-secret"]
    }
  }

  phoenix_client_env = {
    for env in local.environments : env => { PHOENIX_URL = local.phoenix_urls[env] }
  }

  phoenix_client_secret_env = {
    for env in local.environments : env => { PHOENIX_API_KEY = local.phoenix_secret_name[env]["admin-secret"] }
  }
}

resource "google_sql_database" "phoenix" {
  for_each = local.environments
  name     = "phoenix"
  instance = google_sql_database_instance.main[each.key].name
}

resource "random_password" "phoenix_database" {
  for_each = local.environments
  length   = 32
  special  = false
}

resource "google_sql_user" "phoenix" {
  for_each = local.environments
  name     = "phoenix"
  instance = google_sql_database_instance.main[each.key].name
  password = random_password.phoenix_database[each.key].result
}

resource "random_password" "phoenix_secret" {
  for_each    = local.environments
  length      = 48
  special     = false
  min_lower   = 1
  min_numeric = 1
}

resource "random_password" "phoenix_admin_secret" {
  for_each    = local.environments
  length      = 48
  special     = false
  min_lower   = 1
  min_numeric = 1
}

resource "google_project_iam_member" "phoenix_cloudsql" {
  for_each = local.environments
  project  = var.project
  role     = "roles/cloudsql.client"
  member   = google_service_account.runtime["phoenix-${each.key}"].member
}

resource "google_secret_manager_secret" "phoenix" {
  for_each  = local.phoenix_secret_ids
  secret_id = "${var.service}-phoenix-${each.value.name}-${each.value.environment}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.api]
}

resource "google_secret_manager_secret_version" "phoenix_generated" {
  for_each    = { for key, value in local.phoenix_secret_ids : key => value if contains(local.phoenix_generated, value.name) }
  secret      = google_secret_manager_secret.phoenix[each.key].id
  secret_data = local.phoenix_generated_values[each.value.environment][each.value.name]
}

resource "google_secret_manager_secret_version" "phoenix_operator" {
  for_each    = { for key, value in local.phoenix_secret_ids : key => value if contains(local.phoenix_operator, value.name) }
  secret      = google_secret_manager_secret.phoenix[each.key].id
  secret_data = uuid()

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_iam_member" "phoenix" {
  for_each  = local.phoenix_secret_ids
  secret_id = google_secret_manager_secret.phoenix[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runtime["phoenix-${each.value.environment}"].member
}

resource "google_secret_manager_secret_iam_member" "phoenix_client" {
  for_each  = local.adk_instances
  secret_id = google_secret_manager_secret.phoenix["admin-secret-${each.value.environment}"].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runtime[each.key].member
}

resource "google_cloud_run_v2_service" "phoenix" {
  for_each             = local.environments
  name                 = "${var.service}-phoenix-${each.key}"
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = true
  deletion_protection  = each.key == "production"
  labels               = { app = var.service, environment = each.key }

  template {
    service_account                  = google_service_account.runtime["phoenix-${each.key}"].email
    labels                           = { app = var.service, environment = each.key }
    max_instance_request_concurrency = 80
    timeout                          = "300s"

    scaling {
      min_instance_count = each.key == "production" ? 1 : 0
      max_instance_count = 2
    }

    containers {
      name  = "phoenix"
      image = var.phoenix_image

      ports {
        container_port = 6006
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
        cpu_idle          = false
        startup_cpu_boost = true
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      dynamic "env" {
        for_each = local.phoenix_env[each.key]
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.phoenix_secret_env[each.key]
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = 6006
        }
        period_seconds    = 5
        failure_threshold = 30
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.main[each.key].connection_name]
      }
    }
  }

  lifecycle {
    ignore_changes = [client, client_version]
  }

  depends_on = [
    google_project_service.api,
    google_secret_manager_secret_version.phoenix_generated,
    google_secret_manager_secret_version.phoenix_operator,
    google_secret_manager_secret_iam_member.phoenix,
    google_project_iam_member.phoenix_cloudsql,
    google_sql_database.phoenix,
    google_sql_user.phoenix,
  ]
}

resource "google_pubsub_topic" "run_completed" {
  for_each   = local.environments
  name       = "${local.phoenix_topic}-${each.key}"
  depends_on = [google_project_service.api]
}

resource "google_pubsub_topic_iam_member" "run_completed_publisher" {
  for_each = local.environments
  topic    = google_pubsub_topic.run_completed[each.key].name
  role     = "roles/pubsub.publisher"
  member   = google_service_account.runtime["worker-${each.key}"].member
}

resource "google_pubsub_subscription" "eval" {
  for_each                   = local.environments
  name                       = "${local.phoenix_topic}-eval-${each.key}"
  topic                      = google_pubsub_topic.run_completed[each.key].id
  ack_deadline_seconds       = 120
  message_retention_duration = "604800s"

  push_config {
    push_endpoint = google_cloud_run_v2_service.adk["eval-${each.key}"].uri

    oidc_token {
      service_account_email = google_service_account.pubsub_invoker.email
      audience              = google_cloud_run_v2_service.adk["eval-${each.key}"].uri
    }
  }

  retry_policy {
    minimum_backoff = "30s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter[each.key].id
    max_delivery_attempts = 5
  }
}

resource "google_pubsub_subscription_iam_member" "eval_dead_letter_subscriber" {
  for_each     = local.environments
  subscription = google_pubsub_subscription.eval[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}

resource "google_cloud_run_v2_service_iam_member" "pubsub_invokes_eval" {
  for_each = local.environments
  name     = google_cloud_run_v2_service.adk["eval-${each.key}"].name
  location = var.region
  role     = "roles/run.invoker"
  member   = google_service_account.pubsub_invoker.member
}

output "phoenix" {
  description = "Each environment's Phoenix: its URL, the redirect URI of its Google OAuth client, and the secrets to fill."
  value = {
    for env in local.environments : env => {
      url                = google_cloud_run_v2_service.phoenix[env].uri
      oauth_redirect_uri = "${local.phoenix_urls[env]}/oauth2/google/tokens"
      secrets_to_fill = [
        google_secret_manager_secret.phoenix["google-client-id-${env}"].secret_id,
        google_secret_manager_secret.phoenix["google-client-secret-${env}"].secret_id,
      ]
    }
  }
}
