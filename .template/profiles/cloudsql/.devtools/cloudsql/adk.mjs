import { existsSync, writeFileSync } from 'node:fs'
import { basename, join } from 'node:path'

import { kebab } from '../scripts/slug.mjs'
import { die, inRoot, printNext } from '../typescript/scaffold.mjs'
import { SAY, SESSIONS } from './adk-strings.mjs'

export function sessionsOnPostgres(root) {
  const { read, run, emit } = inRoot(root)
  const need = (path, hint) => existsSync(join(root, path)) || die(SAY.missing(path, hint))
  need(SESSIONS.files.cloudsql, SAY.hints.cloudsql)
  need(SESSIONS.files.sessions, SAY.hints.worker)
  if (read(SESSIONS.files.sessions).includes(SESSIONS.databaseMarker)) {
    die(SAY.already(SESSIONS.files.sessions))
  }

  for (const { path, from } of SESSIONS.edits) {
    if (!read(path).includes(from)) die(SAY.missing(path, from.trim()))
  }

  const write = (path, contents) => {
    writeFileSync(join(root, path), contents)
    console.log(SAY.patched(path))
  }
  for (const path of new Set(SESSIONS.edits.map((edit) => edit.path))) {
    const edits = SESSIONS.edits.filter((edit) => edit.path === path)
    write(path, edits.reduce((text, { from, to }) => text.replace(from, to), read(path)))
  }
  write(SESSIONS.files.sessions, read(SESSIONS.templates.sessions))
  const scope = `@${kebab(basename(root))}/`
  emit({
    [SESSIONS.files.sessionsTest]: read(SESSIONS.templates.sessionsTest).replaceAll(
      SESSIONS.scopeToken,
      scope
    )
  })

  const directory = `./${SESSIONS.worker}`
  run('pnpm', ['--filter', directory, 'add', ...SESSIONS.dependencies])
  run('pnpm', ['--filter', directory, 'add', '--save-dev', ...SESSIONS.devDependencies])
  printNext(...SAY.next)
}
