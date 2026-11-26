export const SESSIONS = {
  worker: 'services/worker',
  files: {
    sessions: 'services/worker/src/sessions.ts',
    sessionsTest: 'services/worker/src/sessions.test.ts',
    cloudsql: 'infra/cloudsql.tf',
    adk: '.devtools/adk/gen.mjs'
  },
  templates: {
    sessions: '.devtools/cloudsql/templates/sessions.ts.tpl',
    sessionsTest: '.devtools/cloudsql/templates/sessions.test.ts.tpl'
  },
  scopeToken: '@scope/',
  databaseMarker: 'DatabaseSessionService',
  dependencies: ['@google-cloud/cloud-sql-connector', '@mikro-orm/postgresql'],
  devDependencies: ['@electric-sql/pglite@0.5.17', '@electric-sql/pglite-socket@0.2.20'],
  edits: [
    {
      path: 'infra/service.tf',
      from: '  adk_worker_env = {}\n',
      to: `  adk_worker_env = {
    for env in local.environments : env => {
      INSTANCE_CONNECTION_NAME = google_sql_database_instance.main[env].connection_name
      DB_NAME                  = google_sql_database.app[env].name
      DB_USER                  = google_sql_user.app[env].name
    }
  }
`
    },
    {
      path: 'infra/service.tf',
      from: '  adk_worker_secret_env = {}\n',
      to: `  adk_worker_secret_env = {
    for env in local.environments : env => {
      DB_PASSWORD = {
        secret  = google_secret_manager_secret_iam_member.runtime_database_password[env].secret_id
        version = google_secret_manager_secret_version.database_password[env].version
      }
    }
  }
`
    },
    {
      path: 'infra/cloudsql.tf',
      from: '  database_service = "app"\n',
      to: '  database_service = "worker"\n'
    }
  ]
}

export const SAY = {
  missing: (path, hint) => `${path} is missing: ${hint}`,
  hints: {
    adk: 'list the adk profile and sync',
    cloudsql: 'make -C .devtools cloudsql-gen first',
    worker: 'make -C .devtools adk-gen first'
  },
  already: (path) => `${path} already uses Postgres: nothing to do`,
  patched: (path) => `patched ${path}`,
  next: [
    'make -C .devtools check            # the worker tests run against Postgres in-process',
    'make -C .devtools infra-apply      # the worker gets INSTANCE_CONNECTION_NAME, DB_NAME, DB_USER, DB_PASSWORD',
    'DB_HOST=127.0.0.1 DB_NAME=... DB_USER=... DB_PASSWORD=... for a local Postgres'
  ]
}
