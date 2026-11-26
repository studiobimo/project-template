const tfCloudsql = `locals {
  database_service = "app"
}

variable "cloudsql_tier" {
  description = "The machine tier of each environment's Postgres instance."
  type        = string
  default     = "db-f1-micro"
}

resource "google_project_service" "sqladmin" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_sql_database_instance" "main" {
  for_each            = local.environments
  name                = "\${var.service}-\${each.key}"
  region              = var.region
  database_version    = "POSTGRES_17"
  deletion_protection = each.key == "production"

  settings {
    tier                        = var.cloudsql_tier
    edition                     = "ENTERPRISE"
    availability_type           = "ZONAL"
    deletion_protection_enabled = each.key == "production"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }
  }

  depends_on = [google_project_service.sqladmin]
}

resource "google_sql_database" "app" {
  for_each = local.environments
  name     = "app"
  instance = google_sql_database_instance.main[each.key].name
}

resource "random_password" "database" {
  for_each = local.environments
  length   = 32
  special  = false
}

resource "google_sql_user" "app" {
  for_each = local.environments
  name     = "app"
  instance = google_sql_database_instance.main[each.key].name
  password = random_password.database[each.key].result
}

resource "google_secret_manager_secret" "database_password" {
  for_each  = local.environments
  secret_id = "\${var.service}-\${each.key}-database-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.api]
}

resource "google_secret_manager_secret_version" "database_password" {
  for_each    = local.environments
  secret      = google_secret_manager_secret.database_password[each.key].id
  secret_data = random_password.database[each.key].result
}

resource "google_project_iam_member" "runtime_cloudsql" {
  for_each = local.environments
  project  = var.project
  role     = "roles/cloudsql.client"
  member   = google_service_account.runtime["\${local.database_service}-\${each.key}"].member
}

resource "google_secret_manager_secret_iam_member" "runtime_database_password" {
  for_each  = local.environments
  secret_id = google_secret_manager_secret.database_password[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runtime["\${local.database_service}-\${each.key}"].member
}

output "cloudsql" {
  description = "What each environment's service reads to connect: INSTANCE_CONNECTION_NAME, DB_NAME, DB_USER and, from the secret, DB_PASSWORD."
  value = {
    for env in local.environments : env => {
      instance_connection_name = google_sql_database_instance.main[env].connection_name
      database                 = google_sql_database.app[env].name
      user                     = google_sql_user.app[env].name
      password_secret          = google_secret_manager_secret.database_password[env].secret_id
    }
  }
}
`

export const CLOUDSQL = {
  next: [
    'make -C .devtools infra-apply   # the instances, databases, users and password secrets',
    'set INSTANCE_CONNECTION_NAME, DB_NAME, DB_USER and DB_PASSWORD (from the secret) on the service in infra/'
  ]
}

export const cloudsqlFiles = () => ({ 'infra/cloudsql.tf': tfCloudsql })
