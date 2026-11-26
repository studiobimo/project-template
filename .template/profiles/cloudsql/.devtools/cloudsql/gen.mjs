#!/usr/bin/env node
import { existsSync } from 'node:fs'
import { join } from 'node:path'

import { projectOf, writeNew } from '../gcp-infra/write.mjs'
import { SAY, SESSIONS } from './adk-strings.mjs'
import { CLOUDSQL, cloudsqlFiles } from './scaffold.mjs'

const exitWith = (message, status) => {
  console.error(message)
  process.exit(status)
}

const kinds = {
  infra: ({ root }) => writeNew(root, cloudsqlFiles(), CLOUDSQL.next),
  async adk({ root }) {
    if (!existsSync(join(root, SESSIONS.files.adk))) {
      exitWith(SAY.missing(SESSIONS.files.adk, SAY.hints.adk), 1)
    }
    await (await import('./adk.mjs')).sessionsOnPostgres(root)
  }
}

const [kind = 'infra'] = process.argv.slice(2)
if (!Object.hasOwn(kinds, kind)) exitWith(CLOUDSQL.usage(Object.keys(kinds)), 2)
await kinds[kind](projectOf(import.meta.url))
