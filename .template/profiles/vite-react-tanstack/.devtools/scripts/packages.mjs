#!/usr/bin/env node
import { spawnSync } from 'node:child_process'
import { existsSync, realpathSync } from 'node:fs'
import { dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

import { glyph, packageMessages as say } from './strings.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const [task, ...args] = process.argv.slice(2)
const here = realpathSync(process.cwd())
const name = relative(realpathSync(root), here) || '.'
const isApp = args.some(
  (app) => existsSync(join(root, app)) && realpathSync(join(root, app)) === here
)
const hasSource = existsSync('src')

const fail = (message) => {
  console.error(`${glyph.fail} ${message}`)
  process.exit(1)
}

const run = (command, argv) => {
  const { status } = spawnSync(command, argv, { stdio: 'inherit' })
  if (status !== 0) process.exit(status ?? 1)
}

const changedSince = process.env.AFFECTED_REF
const changed = changedSince ? ['--changed', changedSince] : []
const passWithNoTests = changedSince ? ['--passWithNoTests'] : []

const incrementalTsc = (config) => run('tsc', ['-p', config, '--noEmit', '--incremental'])

const configsOf = (project) => {
  const file = project.endsWith('.json') ? project : join(project, 'tsconfig.json')
  const shown = spawnSync('tsc', ['--showConfig', '-p', file], { encoding: 'utf8' })
  if (shown.status !== 0) {
    process.stderr.write(shown.stdout + shown.stderr)
    process.exit(shown.status ?? 1)
  }
  const references = JSON.parse(shown.stdout).references ?? []
  if (references.length === 0) return [file]
  return references.flatMap(({ path }) => configsOf(join(dirname(file), path)))
}

const tasks = {
  test() {
    if (existsSync('vitest.config.ts')) {
      return run('vitest', ['run', ...changed, ...passWithNoTests])
    }
    if (!hasSource) return
    const config = join(root, '.devtools/vite/vitest.default.ts')
    run('vitest', ['run', '--config', config, '--passWithNoTests', ...changed])
  },
  typecheck() {
    if (isApp || !hasSource) return
    if (!existsSync('tsconfig.json')) fail(say.noTsconfig(name))
    incrementalTsc('tsconfig.json')
  },
  tsc() {
    const configs = new Set(args.flatMap((project) => configsOf(project)))
    for (const config of configs) incrementalTsc(config)
  },
  apps() {
    if (!isApp && existsSync('vite.config.ts')) fail(say.unlistedApp(name))
  }
}

if (!(task in tasks)) fail(say.usage(Object.keys(tasks)))
tasks[task]()
