import {
  DatabaseSessionService,
  InMemorySessionService,
  type BaseSessionService,
  type DatabaseSessionServiceOptions
} from '@google/adk'
import { Connector, IpAddressTypes } from '@google-cloud/cloud-sql-connector'
import { PostgreSqlDriver } from '@mikro-orm/postgresql'

export const SESSIONS = {
  env: {
    instance: 'INSTANCE_CONNECTION_NAME',
    database: 'DB_NAME',
    user: 'DB_USER',
    password: 'DB_PASSWORD',
    host: 'DB_HOST',
    port: 'DB_PORT',
    poolSize: 'DB_POOL_SIZE'
  },
  defaultPort: 5432,
  defaultPoolSize: 5
}

export type ConnectionOptions = (
  instanceConnectionName: string
) => Promise<NonNullable<DatabaseSessionServiceOptions['driverOptions']>>

const connectorOptions: ConnectionOptions = (instanceConnectionName) =>
  new Connector().getOptions({ instanceConnectionName, ipType: IpAddressTypes.PUBLIC })

export async function sessionService(
  env: NodeJS.ProcessEnv = process.env,
  connect: ConnectionOptions = connectorOptions
): Promise<BaseSessionService> {
  const instance = env[SESSIONS.env.instance]
  const host = env[SESSIONS.env.host]
  if (!instance && !host) return new InMemorySessionService()
  const sessions = new DatabaseSessionService({
    driver: PostgreSqlDriver,
    dbName: env[SESSIONS.env.database],
    user: env[SESSIONS.env.user],
    password: env[SESSIONS.env.password],
    pool: { min: 0, max: Number(env[SESSIONS.env.poolSize] ?? SESSIONS.defaultPoolSize) },
    ...(instance
      ? { driverOptions: await connect(instance) }
      : { host, port: Number(env[SESSIONS.env.port] ?? SESSIONS.defaultPort) })
  })
  await sessions.init()
  return sessions
}
