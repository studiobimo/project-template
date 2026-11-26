locals {
  webhook_secrets = toset(["github-webhook-secret", "slack-signing-secret"])
  secret_ids = {
    for pair in setproduct(local.environments, local.webhook_secrets) :
    "${pair[1]}-${pair[0]}" => { environment = pair[0], name = pair[1] }
  }
}

resource "google_secret_manager_secret" "webhook" {
  for_each  = local.secret_ids
  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.api]
}

resource "google_secret_manager_secret_version" "webhook_placeholder" {
  for_each    = local.secret_ids
  secret      = google_secret_manager_secret.webhook[each.key].id
  secret_data = uuid()

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_iam_member" "webhook" {
  for_each  = local.secret_ids
  secret_id = google_secret_manager_secret.webhook[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runtime["ingress-${each.value.environment}"].member
}

resource "google_secret_manager_secret" "collector" {
  secret_id = "otel-collector-config"

  replication {
    auto {}
  }

  depends_on = [google_project_service.api]
}

resource "google_secret_manager_secret_version" "collector" {
  secret      = google_secret_manager_secret.collector.id
  secret_data = file("${path.module}/collector.yaml")
}

resource "google_secret_manager_secret_iam_member" "collector" {
  for_each  = local.adk_instances
  secret_id = google_secret_manager_secret.collector.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runtime[each.key].member
}
