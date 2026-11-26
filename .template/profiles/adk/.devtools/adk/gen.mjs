#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { basename, dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

import { deployEnvsOf, infraFiles } from '../gcp-infra/scaffold.mjs'
import { kebab } from '../scripts/slug.mjs'
import { die, inRoot, printNext } from '../typescript/scaffold.mjs'
import { GEN, SCAFFOLD } from '../typescript/strings.mjs'
import { ADK, SAY } from './strings.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const scope = `@${kebab(basename(root))}/`
const withScope = (text) => text.replaceAll(ADK.scopeToken, scope)
const { read, run, emit, patch } = inRoot(root)

const typescript = (...args) => run('node', ['.devtools/typescript/gen.mjs', ...args])

function filesUnder(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    return entry.isDirectory() ? filesUnder(path) : [path]
  })
}

const templateFiles = () => {
  const base = join(root, ADK.dirs.templates)
  return Object.fromEntries(
    filesUnder(base).map((path) => [
      relative(base, path).slice(0, -ADK.templateSuffix.length),
      withScope(readFileSync(path, 'utf8'))
    ])
  )
}

function patchPackage(directory, { exports, scripts = {} }) {
  const path = join(root, directory, 'package.json')
  const manifest = JSON.parse(readFileSync(path, 'utf8'))
  if (exports) {
    manifest.exports = {
      '.': { types: exports.replace(/\.js$/, '.d.ts'), default: exports }
    }
  }
  manifest.scripts = { ...manifest.scripts, ...scripts }
  writeFileSync(path, `${JSON.stringify(manifest, null, 2)}\n`)
}

const pnpmAdd = (directory, dependencies, flags = []) =>
  dependencies?.length > 0 &&
  run('pnpm', ['--filter', `./${directory}`, 'add', ...flags, ...dependencies.map(withScope)])

function allowBuilds() {
  const file = 'pnpm-workspace.yaml'
  const current = read(file)
  const missing = ADK.allowBuilds.filter((name) => !current.includes(`'${name}'`))
  if (missing.length === 0) return
  const entries = missing.map((name) => `  '${name}': false\n`).join('')
  const key = /^allowBuilds:\n/m
  const marker = '# >>> template:typescript'
  const updated = key.test(current)
    ? current.replace(key, (line) => `${line}${entries}`)
    : current.replace(marker, `allowBuilds:\n${entries}\n${marker}`)
  writeFileSync(join(root, file), updated)
}

function knipEntries() {
  const path = join(root, 'knip.json')
  const config = JSON.parse(readFileSync(path, 'utf8'))
  config.workspaces = {
    ...config.workspaces,
    ...Object.fromEntries(Object.entries(ADK.knipEntries).map(([name, entry]) => [name, { entry }]))
  }
  writeFileSync(path, `${JSON.stringify(config, null, 2)}\n`)
}

function contractExports() {
  const file = join(root, ADK.dirs.contracts, 'src', 'index.ts')
  const current = readFileSync(file, 'utf8')
  const missing = ADK.contractExports.filter((line) => !current.includes(line))
  writeFileSync(file, `${current}${missing.join('\n')}\n`)
}

function runtimeServicesEdits(text) {
  if (!text) return []
  const list = text.match(ADK.runtimeServices)
  if (!list) die(SAY.runtimeServices(ADK.files.runtime))
  const listed = [...list[1].matchAll(/"([^"]+)"/g)].map(([, name]) => name)
  const added = ADK.services.filter((name) => !listed.includes(name))
  const names = [...listed, ...added].map((name) => `"${name}"`).join(', ')
  return added.length === 0 ? [] : [{ from: list[0], to: `runtime_services = toset([${names}])` }]
}

const kinds = {
  agents() {
    if (!existsSync(join(root, ADK.dirs.contracts))) die(SAY.noWorkspace(GEN.commands.gen))
    const directories = [
      ...ADK.libraries.map((name) => `packages/${name}`),
      ...ADK.services.map((name) => `${GEN.dirs.services}/${name}`)
    ]
    const taken = directories.filter((directory) => existsSync(join(root, directory)))
    if (taken.length > 0) die(SCAFFOLD.refusing(taken))

    for (const name of ADK.libraries) typescript('package', name)
    for (const name of ADK.services) {
      typescript('service', name)
      for (const sample of [...ADK.sampleFiles, 'src/index.ts']) {
        rmSync(join(root, GEN.dirs.services, name, sample))
      }
    }

    const runtimeEdits = runtimeServicesEdits(read(ADK.files.runtime))
    if (runtimeEdits.length > 0) patch(ADK.files.runtime, runtimeEdits)

    const base = infraFiles({
      slug: kebab(basename(root)),
      deployEnvs: deployEnvsOf(read('.devtools/Makefile')),
      runtimeServices: ADK.services
    })
    const missingInfra = Object.fromEntries(
      Object.entries(base).filter(([path]) => !existsSync(join(root, path)))
    )
    emit({ ...templateFiles(), ...missingInfra })
    contractExports()
    allowBuilds()
    knipEntries()

    for (const [name, spec] of Object.entries(ADK.packages)) {
      const directory = ADK.libraries.includes(name)
        ? `packages/${name}`
        : `${GEN.dirs.services}/${name}`
      patchPackage(directory, spec)
      pnpmAdd(directory, spec.dependencies)
      pnpmAdd(directory, spec.devDependencies, ['--save-dev'])
    }
    run('pnpm', ['install'])
    run('make', ['-C', '.devtools', 'adk-graphs'])
    printNext(...SAY.next)
  }
}

const [kind] = process.argv.slice(2)
if (!Object.hasOwn(kinds, kind)) die(SAY.usage(Object.keys(kinds)))
kinds[kind]()
