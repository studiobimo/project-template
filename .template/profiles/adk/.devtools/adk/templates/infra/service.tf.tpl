variable "claude_location" {
  description = "Where Claude on Vertex AI runs: us-east5, europe-west1 or global. Gemini runs in var.region."
  type        = string
  default     = "us-east5"
}

locals {
  request_timeout_seconds = 300

  adk_services = toset(["ingress", "worker"])
  adk_instances = {
    for pair in setproduct(local.environments, local.adk_services) :
    "${pair[1]}-${pair[0]}" => { environment = pair[0], service = pair[1] }
  }
  collector_image = "us-docker.pkg.dev/cloud-ops-agents-artifacts/google-cloud-opentelemetry-collector/otelcol-google:0.128.0"

  adk_worker_env = {}

  adk_worker_secret_env = {}
}

resource "google_project_iam_member" "runtime_vertex" {
  for_each = local.environments
  project  = var.project
  role     = "roles/aiplatform.user"
  member   = google_service_account.runtime["worker-${each.key}"].member
}

resource "google_cloud_run_v2_service" "adk" {
  for_each             = local.adk_instances
  name                 = "${var.service}-${each.key}"
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = each.value.service == "ingress"
  deletion_protection  = each.value.environment == "production"
  labels               = { app = var.service, environment = each.value.environment }

  template {
    service_account                  = google_service_account.runtime[each.key].email
    labels                           = { app = var.service, environment = each.value.environment }
    max_instance_request_concurrency = each.value.service == "worker" ? 4 : 80
    timeout                          = "${local.request_timeout_seconds}s"

    scaling {
      min_instance_count = 0
      max_instance_count = each.value.environment == "production" ? 5 : 2
    }

    containers {
      name       = "app"
      image      = "us-docker.pkg.dev/cloudrun/container/hello"
      depends_on = ["collector"]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      env {
        name  = "GOOGLE_GENAI_USE_VERTEXAI"
        value = "true"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project
      }
      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = var.region
      }
      env {
        name  = "CLAUDE_LOCATION"
        value = var.claude_location
      }
      env {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "http://localhost:4318"
      }
      env {
        name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
        value = "http/protobuf"
      }
      env {
        name  = "OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT"
        value = each.value.environment == "production" ? "false" : "true"
      }
      env {
        name  = "ADK_CAPTURE_MESSAGE_CONTENT_IN_SPANS"
        value = each.value.environment == "production" ? "false" : "true"
      }
      env {
        name  = "PUBSUB_TOPIC_SUFFIX"
        value = "-${each.value.environment}"
      }

      dynamic "env" {
        for_each = each.value.service == "worker" ? lookup(local.adk_worker_env, each.value.environment, {}) : {}
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = each.value.service == "worker" ? lookup(local.adk_worker_secret_env, each.value.environment, {}) : {}
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }

      dynamic "env" {
        for_each = each.value.service == "ingress" ? {
          GITHUB_WEBHOOK_SECRET = "github-webhook-secret-${each.value.environment}"
          SLACK_SIGNING_SECRET  = "slack-signing-secret-${each.value.environment}"
        } : {}
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.webhook[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }

    containers {
      name  = "collector"
      image = local.collector_image
      args  = ["--config=/etc/otelcol/config.yaml"]

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
      }

      volume_mounts {
        name       = "collector-config"
        mount_path = "/etc/otelcol"
      }

      startup_probe {
        http_get {
          path = "/"
          port = 13133
        }
        period_seconds    = 2
        failure_threshold = 15
      }
    }

    volumes {
      name = "collector-config"
      secret {
        secret = google_secret_manager_secret.collector.secret_id
        items {
          version = "latest"
          path    = "config.yaml"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
    ]
  }

  depends_on = [
    google_project_service.api,
    google_secret_manager_secret_version.collector,
    google_secret_manager_secret_version.webhook_placeholder,
    google_secret_manager_secret_iam_member.collector,
    google_secret_manager_secret_iam_member.webhook,
  ]
}

output "adk_urls" {
  description = "Each service's URL, by <service>-<environment>."
  value       = { for name, service in google_cloud_run_v2_service.adk : name => service.uri }
}
