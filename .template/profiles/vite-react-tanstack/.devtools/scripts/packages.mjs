#!/usr/bin/env node
// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// One check, run in the workspace package it starts in. vite.mk runs it in every package with
// `pnpm --recursive exec`, so a new package is covered by what it has, not by a list in
// Makefile:
//
//   packages.mjs test                 vitest run: the package's vitest.config.ts, or the shared
//                                     default when it has none. Only a package with a src/.
//   packages.mjs typecheck <app>...   tsc -b. A package with a src/ and no tsconfig.json fails.
//                                     The apps are type-checked by typecheck-app, not here.
//   packages.mjs apps <app>...        fails on a package with a vite.config.ts that is not one
//                                     of the apps, since only an app has a build and a budget
//
// <app> is an app's directory from the repository's root, as APPS and APP_DIR list it.
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
