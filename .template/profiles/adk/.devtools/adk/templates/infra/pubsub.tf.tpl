locals {
  topic_name       = "pr-events"
  dead_letter_name = "pr-events-dead-letter"
}

resource "google_pubsub_topic" "events" {
  for_each   = local.environments
  name       = "${local.topic_name}-${each.key}"
  depends_on = [google_project_service.api]
}

resource "google_pubsub_topic" "dead_letter" {
  for_each   = local.environments
  name       = "${local.dead_letter_name}-${each.key}"
  depends_on = [google_project_service.api]
}

resource "google_pubsub_subscription" "dead_letter" {
  for_each             = local.environments
  name                 = "${local.dead_letter_name}-${each.key}"
  topic                = google_pubsub_topic.dead_letter[each.key].id
  ack_deadline_seconds = 60
}

resource "google_service_account" "pubsub_invoker" {
  account_id   = "pubsub-invoker"
  display_name = "Pub/Sub: pushes to the workers"
}

resource "google_pubsub_subscription" "worker" {
  for_each                   = local.environments
  name                       = "${local.topic_name}-worker-${each.key}"
  topic                      = google_pubsub_topic.events[each.key].id
  ack_deadline_seconds       = local.request_timeout_seconds
  enable_message_ordering    = true
  message_retention_duration = "604800s"

  push_config {
    push_endpoint = google_cloud_run_v2_service.adk["worker-${each.key}"].uri

    oidc_token {
      service_account_email = google_service_account.pubsub_invoker.email
      audience              = google_cloud_run_v2_service.adk["worker-${each.key}"].uri
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter[each.key].id
    max_delivery_attempts = 5
  }
}

locals {
  pubsub_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  for_each = local.environments
  topic    = google_pubsub_topic.dead_letter[each.key].name
  role     = "roles/pubsub.publisher"
  member   = local.pubsub_agent
}

resource "google_pubsub_subscription_iam_member" "dead_letter_subscriber" {
  for_each     = local.environments
  subscription = google_pubsub_subscription.worker[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}

resource "google_pubsub_topic_iam_member" "ingress_publisher" {
  for_each = local.environments
  topic    = google_pubsub_topic.events[each.key].name
  role     = "roles/pubsub.publisher"
  member   = google_service_account.runtime["ingress-${each.key}"].member
}

resource "google_cloud_run_v2_service_iam_member" "pubsub_invokes_worker" {
  for_each = local.environments
  name     = google_cloud_run_v2_service.adk["worker-${each.key}"].name
  location = var.region
  role     = "roles/run.invoker"
  member   = google_service_account.pubsub_invoker.member
}
