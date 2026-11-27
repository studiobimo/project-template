<!-- markdownlint-disable-file MD041 -- only the block is synced, into a full AGENTS.md -->
<!-- >>> template:cloudsql -->
## Database: Cloud SQL

The `cloudsql` profile keeps this section, `.devtools/cloudsql.mk` and `.devtools/cloudsql/`
in step with the template, on top of `gcp-infra`, which has to be listed before it.
`infra/cloudsql.tf` is the project's: `make -C .devtools cloudsql-gen` writes a first version
where there is none, then `infra-apply`.

- **One Postgres 17 instance per environment**, `<service>-<environment>`, on `db-f1-micro`
  (`cloudsql_tier`), zonal, with backups and point-in-time recovery. Production has deletion
  protection; remove it in `infra/cloudsql.tf` before destroying it.
- **Private by design.** The instance has a public IP but no authorized network and requires
  TLS: only the Cloud SQL connector, which checks IAM, connects. No VPC.
- **Credentials.** Database `app`, user `app`, a generated password in Secret Manager as
  `<service>-<environment>-database-password`. One runtime account gets `roles/cloudsql.client`
  and `roles/secretmanager.secretAccessor` on that secret only: `<database_service>-<environment>`,
  with `local.database_service` in `infra/cloudsql.tf` (`app`, or `worker` once
  `cloudsql-adk-gen` has run). The public ingress never holds database access.
- **A service reads** these, set on it in `infra/`; `tofu output cloudsql` lists the values:

  | Variable | From |
  | --- | --- |
  | `INSTANCE_CONNECTION_NAME` | `instance_connection_name` |
  | `DB_NAME` | `database` |
  | `DB_USER` | `user` |
  | `DB_PASSWORD` | the `password_secret`, as a secret env var |

- **Connect** with `@google-cloud/cloud-sql-connector` and `pg`: the connector's
  `getOptions({ instanceConnectionName, ipType: 'PUBLIC' })` goes into the `pg` `Pool` with
  `user`, `password` and `database`. Add the packages in the project that connects.
- **Why the HCL has no comments.** The instance has a public IP but no authorized network, so
  only the Cloud SQL connector, which checks IAM and encrypts, gets in.
<!-- <<< template:cloudsql -->
