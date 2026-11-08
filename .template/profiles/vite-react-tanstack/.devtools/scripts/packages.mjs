#!/usr/bin/env node
import { spawnSync } from 'node:child_process'
import { existsSync, realpathSync } from 'node:fs'
import { dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

import { glyph, packageMessages as say } from './strings.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const [task, ...apps] = process.argv.slice(2)
const here = realpathSync(process.cwd())
const name = relative(realpathSync(root), here) || '.'
const isApp = apps.some(
  (app) => existsSync(join(root, app)) && realpathSync(join(root, app)) === here
)
const hasSource = existsSync('src')

const fail = (message) => {
  console.error(`${glyph.fail} ${message}`)
  process.exit(1)
}

const run = (command, args) => {
  const { status } = spawnSync(command, args, { stdio: 'inherit' })
  if (status !== 0) process.exit(status ?? 1)
}

const tasks = {
  test() {
    if (existsSync('vitest.config.ts')) return run('vitest', ['run'])
    if (!hasSource) return
    const config = join(root, '.devtools/vite/vitest.default.ts')
    run('vitest', ['run', '--config', config, '--passWithNoTests'])
  },
  typecheck() {
    if (isApp || !hasSource) return
    if (!existsSync('tsconfig.json')) fail(say.noTsconfig(name))
    run('tsc', ['-b'])
  },
  apps() {
    if (!isApp && existsSync('vite.config.ts')) fail(say.unlistedApp(name))
  }
}

if (!(task in tasks)) fail(say.usage(Object.keys(tasks)))
tasks[task]()
