#!/usr/bin/env node
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { basename, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { kebab } from '../scripts/slug.mjs'
import { die, inRoot, missingAnchor, printNext, templateFiles } from '../typescript/scaffold.mjs'
import { GEN } from '../typescript/strings.mjs'
import { PHOENIX, SAY } from './strings.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const slug = kebab(basename(root))
const scope = `@${slug}/`
const withScope = (text) => text.replaceAll(PHOENIX.scopeToken, scope)
const { read, run, emit, patch, add } = inRoot(root)

const strip = PHOENIX.contentAttributes
  .map((name) => `${PHOENIX.stripIndent}- delete_key(attributes, "${name}")`)
  .join('\n')

const patchText = (name) =>
  withScope(read(join(PHOENIX.dirs.patches, name)))
    .replaceAll(PHOENIX.tokens.strip, strip)
    .replaceAll(PHOENIX.tokens.project, slug)

const text = (value) => (value.endsWith(PHOENIX.templateSuffix) ? patchText(value) : value)

const scoped = (edit) =>
  Object.fromEntries(Object.entries(edit).map(([key, value]) => [key, withScope(value)]))

const EDITS = Object.fromEntries(
  Object.entries(PHOENIX.edits).map(([path, edits]) => [path, edits.map(scoped)])
)

const resolve = ({ from, to, after, before, patch: replacement }) => ({
  from,
  to:
    to !== undefined
      ? text(to)
      : replacement !== undefined
        ? text(replacement)
        : after !== undefined
          ? `${from}${text(after)}`
          : `${text(before)}${from}`
})

const need = (path, hint) => existsSync(join(root, path)) || die(SAY.missing(path, hint))

function preflight() {
  need(PHOENIX.needs.cloudsql, SAY.hints.cloudsql)
  need(PHOENIX.needs.adk, SAY.hints.adk)
  need(PHOENIX.needs.worker, SAY.hints.adk)
  for (const [path, edits] of Object.entries(EDITS)) {
    const anchor = missingAnchor(read(path), edits)
    if (anchor !== undefined) die(SAY.missing(path, JSON.stringify(anchor)))
  }
}

function patchPackage(directory, { main }) {
  const path = join(root, directory, 'package.json')
  const manifest = JSON.parse(readFileSync(path, 'utf8'))
  if (main) manifest.main = main
  writeFileSync(path, `${JSON.stringify(manifest, null, 2)}\n`)
}

preflight()
const service = `${GEN.dirs.services}/${PHOENIX.evalService}`
run('node', ['.devtools/typescript/gen.mjs', 'service', PHOENIX.evalService])
for (const sample of PHOENIX.sampleFiles) rmSync(join(root, service, sample))
emit(templateFiles(join(root, PHOENIX.dirs.templates), PHOENIX.templateSuffix, withScope))
for (const [path, edits] of Object.entries(EDITS)) patch(path, edits.map(resolve))
patchPackage(service, PHOENIX.packages.eval)
add(service, PHOENIX.packages.eval.dependencies.map(withScope))
add(service, PHOENIX.packages.eval.devDependencies, ['--save-dev'])
add(`${GEN.dirs.services}/worker`, PHOENIX.packages.worker.dependencies)
run('pnpm', ['install'])
printNext(...SAY.next)
