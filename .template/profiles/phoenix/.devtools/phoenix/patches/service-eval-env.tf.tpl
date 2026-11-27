      dynamic "env" {
        for_each = each.value.service == "eval" ? lookup(local.phoenix_client_env, each.value.environment, {}) : {}
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = each.value.service == "eval" ? lookup(local.phoenix_client_secret_env, each.value.environment, {}) : {}
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
