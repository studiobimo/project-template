#!/usr/bin/env node
import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { basename, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { GEN, GLYPH, MESSAGES } from './strings.mjs'

const say = MESSAGES.gen
const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const read = (path) => (existsSync(join(root, path)) ? readFileSync(join(root, path), 'utf8') : '')

const die = (message) => {
  console.error(`${GLYPH.fail} ${message}`)
  process.exit(1)
}

const kebab = (name) =>
  name
    .replace(/([a-z0-9])([A-Z])/g, '$1-$2')
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .map((word) => word.toLowerCase())
    .join('-')

const slug = kebab(basename(root))
const scope = `@${slug}`
const nodeMajor = read('mise.toml').match(/^node = "(\d+)/m)?.[1] ?? '24'
const pnpmVersion = read('mise.toml').match(/^pnpm = "([^"]+)"/m)?.[1]
const json = (value) => `${JSON.stringify(value, null, 2)}\n`

function emit(files) {
  const taken = Object.keys(files).filter((path) => existsSync(join(root, path)))
  if (taken.length > 0) die(say.refusing(taken))
  for (const [path, contents] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true })
    writeFileSync(join(root, path), contents)
    console.log(say.created(path))
  }
}

function run(command, args) {
  console.log(say.running(command, args))
  const { status, error } = spawnSync(command, args, { cwd: root, stdio: 'inherit' })
  if (error || status !== 0) die(say.failed(command, args))
}

const printNext = (...lines) => console.log(say.next(lines))

const shared = '../../.devtools/typescript'
const packageFiles = (name, manifest) => ({
  'package.json': json({
    name,
    private: true,
    type: 'module',
    ...manifest,
    files: ['dist'],
    scripts: {
      ...manifest.scripts,
      build: 'tsc -p tsconfig.build.json',
      typecheck: 'tsc -p tsconfig.json --noEmit',
      test: `vitest run --config ${shared}/vitest.ts`
    }
  }),
  'tsconfig.json': json({ extends: `${shared}/tsconfig.package.json` }),
  'tsconfig.build.json': json({ extends: `${shared}/tsconfig.build.json` })
})

const inDir = (dir, files) =>
  Object.fromEntries(Object.entries(files).map(([path, contents]) => [join(dir, path), contents]))

const rootFiles = {
  'package.json': json({
    name: slug,
    private: true,
    type: 'module',
    devEngines: { packageManager: { name: 'pnpm', version: pnpmVersion } }
  }),
  'turbo.json': json({
    $schema: 'https://turborepo.com/schema.json',
    globalDependencies: [
      'pnpm-lock.yaml',
      'pnpm-workspace.yaml',
      'mise.lock',
      '.devtools/typescript/**'
    ],
    tasks: {
      build: { dependsOn: ['^build'], outputs: ['dist/**'] },
      typecheck: { dependsOn: ['^build'] },
      test: { dependsOn: ['^build'] }
    }
  }),
  'eslint.config.js': `import { defineConfig } from 'eslint/config'

import { base } from './.devtools/typescript/eslint.js'

export default defineConfig([base])
`,
  'knip.json': json({
    $schema: 'https://unpkg.com/knip@6/schema.json',
    ignore: ['.devtools/**'],
    ignoreDependencies: ['turbo']
  })
}

const toolDependencies = [
  'turbo',
  'typescript@~6.0.3',
  `@types/node@^${nodeMajor}`,
  'vitest',
  'eslint',
  '@eslint/js',
  'typescript-eslint',
  'globals',
  'knip'
]

const contractsFiles = inDir(GEN.dirs.contracts, {
  ...packageFiles(`${scope}/contracts`, {
    exports: { '.': { types: './dist/index.d.ts', default: './dist/index.js' } }
  }),
  'src/index.ts': `export { greetingRequested } from './greeting.ts'
export { defineTopic } from './topic.ts'
`,
  'src/topic.ts': `import type { z } from 'zod'

const encoder = new TextEncoder()
const decoder = new TextDecoder()

export function defineTopic<Schema extends z.ZodType>(name: string, schema: Schema) {
  return {
    name,
    schema,
    encode: (payload: z.input<Schema>): Uint8Array =>
      encoder.encode(JSON.stringify(schema.parse(payload))),
    decode: (data: Uint8Array): z.output<Schema> => schema.parse(JSON.parse(decoder.decode(data)))
  }
}
`,
  'src/greeting.ts': `import { z } from 'zod'

import { defineTopic } from './topic.ts'

export const greetingRequested = defineTopic(
  'greeting-requested',
  z.object({ name: z.string().min(1) })
)
`,
  'src/topic.test.ts': `import { describe, expect, it } from 'vitest'
import { z } from 'zod'

import { defineTopic } from './topic.ts'

const topic = defineTopic('example', z.object({ id: z.string() }))
const bytes = (text: string) => new TextEncoder().encode(text)

describe('defineTopic', () => {
  it('round-trips a valid payload', () => {
    expect(topic.decode(topic.encode({ id: 'a' }))).toEqual({ id: 'a' })
  })

  it('refuses to publish an invalid payload', () => {
    expect(() => topic.encode({ id: 1 } as never)).toThrow()
  })

  it('refuses to consume an invalid message', () => {
    expect(() => topic.decode(bytes('{"id":1}'))).toThrow()
    expect(() => topic.decode(bytes('not json'))).toThrow()
  })
})
`
})

const serviceFiles = (name) =>
  inDir(join(GEN.dirs.services, name), {
    ...packageFiles(`${scope}/${name}`, {
      main: 'dist/index.js',
      scripts: { start: 'node dist/index.js' }
    }),
    'src/handler.ts': `import { greetingRequested } from '${scope}/contracts'

export interface Reply {
  status: number
  body: string
}

export function handle(data: Uint8Array): Reply {
  try {
    const { name } = greetingRequested.decode(data)
    return { status: 200, body: \`Hello, \${name}\` }
  } catch (error) {
    return { status: 400, body: error instanceof Error ? error.message : String(error) }
  }
}
`,
    'src/index.ts': `import { createServer } from 'node:http'

import { handle } from './handler.ts'

const port = Number(process.env.PORT ?? 8080)

const server = createServer((request, response) => {
  const chunks: Buffer[] = []
  request.on('data', (chunk: Buffer) => chunks.push(chunk))
  request.on('end', () => {
    const { status, body } = handle(Buffer.concat(chunks))
    response.writeHead(status).end(body)
  })
})

server.listen(port)
process.on('SIGTERM', () => server.close(() => process.exit(0)))
`,
    'src/handler.test.ts': `import { greetingRequested } from '${scope}/contracts'
import { describe, expect, it } from 'vitest'

import { handle } from './handler.ts'

describe('handle', () => {
  it('greets the name in a valid message', () => {
    expect(handle(greetingRequested.encode({ name: 'Ada' }))).toEqual({
      status: 200,
      body: 'Hello, Ada'
    })
  })

  it('answers 400 to a message that breaks the contract', () => {
    expect(handle(new TextEncoder().encode('{"name":""}')).status).toBe(400)
  })
})
`
  })

function ensureWorkspacePackages() {
  const file = join(root, 'pnpm-workspace.yaml')
  const current = read('pnpm-workspace.yaml')
  if (/^packages:/m.test(current)) return
  const packages = `packages:\n  - packages/*\n  - ${GEN.dirs.services}/*\n\n`
  writeFileSync(file, packages + current)
}

const kinds = {
  workspace() {
    emit({ ...rootFiles, ...contractsFiles })
    ensureWorkspacePackages()
    run('pnpm', ['add', '--save-dev', '--workspace-root', ...toolDependencies])
    run('pnpm', ['--filter', `./${GEN.dirs.contracts}`, 'add', 'zod'])
    printNext(MESSAGES.next.service, MESSAGES.next.check, MESSAGES.next.commit)
  },
  service(name) {
    if (!name || !/^[a-z][a-z0-9-]*$/.test(name)) die(say.usageService)
    if (!existsSync(join(root, GEN.dirs.contracts))) die(say.noWorkspace)
    emit(serviceFiles(name))
    run('pnpm', [
      '--filter',
      `./${GEN.dirs.services}/${name}`,
      'add',
      `${scope}/contracts@workspace:*`
    ])
    printNext(MESSAGES.next.image(name), MESSAGES.next.check, MESSAGES.next.commit)
  }
}

const [kind, name] = process.argv.slice(2)
if (!Object.hasOwn(kinds, kind)) die(say.usage(Object.keys(kinds)))
kinds[kind](name)
