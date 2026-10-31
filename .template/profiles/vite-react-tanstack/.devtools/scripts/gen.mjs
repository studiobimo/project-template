#!/usr/bin/env node
// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// Scaffolds on-convention code, so a new file starts formatted, lint-clean and tested
// rather than copied from whichever file was nearest. It never overwrites a file. The paths
// below are from APP_DIR, which .devtools/Makefile sets for an app in a workspace.
//
//   gen.mjs app [--no-install]           the config, router and i18n wiring a new project
//                                        needs, and the hosting profile's files if there is
//                                        one; then installs the packages and builds once
//   gen.mjs host [--no-install]          the hosting profile's files, for an app that has
//                                        been running without one
//   gen.mjs route <path> [--feature <f>] a file route, src/routes/<path>.tsx; with
//                                        --feature it loads and renders that feature's page
//   gen.mjs feature <name>               src/features/<name>/: schema, query, page and test,
//                                        and the page's strings in src/locales/*/<name>.json
//   gen.mjs component <name>             src/components/<name>.tsx and its test
//   gen.mjs hook <name>                  src/hooks/use-<name>.ts and its test
//
// Names take any casing: user-profile, userProfile and UserProfile are the same. A route is
// named by its id, the URL path plus any layout and group folders it sits in: /users/$userId,
// /settings/ (a trailing slash is an index route), /_auth/account (inside the pathless
// _auth layout), /(marketing)/pricing (in the marketing group, served at /pricing).
import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { basename, dirname, join, relative } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { parseArgs } from 'node:util'

import { genMessages as say, genNext, glyph } from './strings.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')

const read = (path) => (existsSync(join(root, path)) ? readFileSync(join(root, path), 'utf8') : '')

// vite.mk's APP_DIR, read from the line in the project's Makefile that sets it.
const appDir = read('.devtools/Makefile').match(/^APP_DIR\s*[:?]?=\s*(\S+)/m)?.[1] ?? '.'
const app = join(root, appDir)
const workspace = appDir !== '.'

const die = (message) => {
  console.error(`${glyph.fail} ${message}`)
  process.exit(1)
}

const words = (name) =>
  name
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .map((word) => word.toLowerCase())
const kebab = (name) => words(name).join('-')
const pascal = (name) =>
  words(name)
    .map((word) => word[0].toUpperCase() + word.slice(1))
    .join('')
const camel = (name) => {
  const p = pascal(name)
  return p[0].toLowerCase() + p.slice(1)
}

/**
 * Writes every file or none: one that already exists stops the run before anything is written.
 * Paths in `appFiles` are from APP_DIR, those in `repoFiles` from the repository's root.
 */
function emit(appFiles, repoFiles = {}) {
  const files = { ...repoFiles }
  for (const [path, contents] of Object.entries(appFiles)) files[join(appDir, path)] = contents
  const taken = Object.keys(files).filter((path) => existsSync(join(root, path)))
  if (taken.length > 0) die(say.refusing(taken))
  for (const [path, contents] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true })
    writeFileSync(join(root, path), contents)
    console.log(say.created(path))
  }
  format(Object.keys(files))
  return Object.keys(files)
}

// Templates cannot know how long a name will be, so the project's own Prettier has the last
// word on line breaks. Before the first install there is none, and `app` formats afterwards.
function format(paths) {
  const prettier = join(root, 'node_modules', '.bin', 'prettier')
  const web = paths.filter((path) => /\.(js|mjs|ts|tsx|css|html)$/.test(path))
  if (web.length > 0 && existsSync(prettier)) {
    spawnSync(prettier, ['--write', '--log-level=warn', ...web], { cwd: root, stdio: 'inherit' })
  }
}

function run(command, args) {
  console.log(say.running(command, args))
  const { status, error } = spawnSync(command, args, { cwd: app, stdio: 'inherit' })
  if (error || status !== 0) die(say.failed(command, args))
}

/**
 * The project's name, slug and Node major, as init and mise.toml left them, and `repo`, the
 * path from the app back to the repository's root.
 */
function project() {
  // The starter README init writes is a heading and the one-line description.
  const readme = read('README.md')
  const slug = kebab(basename(root))
  const name = readme.match(/^# (.+)$/m)?.[1].trim() ?? pascal(slug)
  const description = readme.match(/^# .+\n+([^#\n].+)$/m)?.[1].trim() ?? name
  const nodeMajor = read('mise.toml').match(/^node = "(\d+)/m)?.[1] ?? '24'
  return { slug, name, description, nodeMajor, repo: relative(app, root) || '.' }
}

/**
 * What the hosting profile's .devtools/host/scaffold.mjs writes and installs: its default
 * export takes project() and returns { files, dependencies, devDependencies, next }.
 */
async function hostScaffold() {
  const path = join(root, '.devtools', 'host', 'scaffold.mjs')
  if (!existsSync(path)) return undefined
  const {
    files = {},
    dependencies = [],
    devDependencies = [],
    next = []
  } = (await import(pathToFileURL(path).href)).default(project())
  return { files, dependencies, devDependencies, next }
}

/** `tools` are what .devtools/ imports, and Node resolves those upward from .devtools/. */
function install(dependencies, devDependencies, tools) {
  const add = (packages, flags) => {
    if (packages.length > 0) run('pnpm', ['add', ...flags, ...packages])
  }
  add(dependencies, [])
  add(devDependencies, ['--save-dev'])
  add(tools, ['--save-dev', '--workspace-root'])
}

/** The languages the app has catalogs for, the default one if it has none yet. */
function languages() {
  const dir = join(app, 'src', 'locales')
  const found = existsSync(dir)
    ? readdirSync(dir, { withFileTypes: true }).filter((entry) => entry.isDirectory())
    : []
  return found.length > 0 ? found.map((entry) => entry.name) : ['en']
}

const next = (...lines) => console.log(say.next(lines))

/** Maps a URL path to its route file and the id createFileRoute takes. */
function routeOf(path) {
  if (!path.startsWith('/')) die(say.routeNoSlash(path))
  const segments = path.slice(1).split('/')
  const index = segments.at(-1) === ''
  if (index) segments.pop()
  for (const segment of segments) {
    if (!/^[\w$.()-]+$/.test(segment) || /^\.+$/.test(segment) || segment === '__root') {
      die(say.routeBadSegment(segment, path))
    }
  }
  const file = [...segments, ...(index || segments.length === 0 ? ['index'] : [])].join('/')
  // The id keeps groups and pathless layouts, which the URL leaves out.
  const id = `/${segments.join('/')}${index && segments.length > 0 ? '/' : ''}`
  return { file: `src/routes/${file}.tsx`, id }
}

const generators = {
  route([path], { feature }) {
    if (!path) die(say.usageRoute)
    const { file, id } = routeOf(path)
    if (!feature) {
      const Name = `${pascal(id) || 'Index'}Route`
      emit({
        [file]: `import { createFileRoute, Outlet } from '@tanstack/react-router'

export const Route = createFileRoute('${id}')({
  component: ${Name}
})

function ${Name}() {
  return <Outlet />
}
`
      })
    } else {
      const k = kebab(feature)
      if (!existsSync(join(app, `src/features/${k}/queries.ts`))) {
        die(say.noFeature(k))
      }
      emit({
        [file]: `import { createFileRoute } from '@tanstack/react-router'

import { ${pascal(feature)}Page } from '@/features/${k}/${k}-page'
import { ${camel(feature)}QueryOptions } from '@/features/${k}/queries'

export const Route = createFileRoute('${id}')({
  loader: ({ context }) => context.queryClient.ensureQueryData(${camel(feature)}QueryOptions()),
  component: ${pascal(feature)}Page
})
`
      })
    }
    next(genNext.route)
  },

  feature([name]) {
    if (!name) die(say.usageFeature)
    const k = kebab(name)
    const P = pascal(name)
    const c = camel(name)
    const dir = `src/features/${k}`
    // Every language starts from the same strings, so the catalogs keep the same keys; a
    // translator replaces them.
    const title = words(name).join(' ')
    const catalog = { title: title[0].toUpperCase() + title.slice(1) }
    const catalogs = Object.fromEntries(
      languages().map((language) => [
        `src/locales/${language}/${k}.json`,
        `${JSON.stringify(catalog, null, 2)}\n`
      ])
    )
    emit({
      ...catalogs,
      [`${dir}/schema.ts`]: `import { z } from 'zod'

export const ${c}Schema = z.object({
  id: z.string()
})

export type ${P} = z.infer<typeof ${c}Schema>
`,
      [`${dir}/queries.ts`]: `import { queryOptions } from '@tanstack/react-query'

import { ${c}Schema } from './schema'

export const ${c}Keys = {
  all: ['${k}'] as const
}

export function ${c}QueryOptions() {
  return queryOptions({
    queryKey: ${c}Keys.all,
    queryFn: async ({ signal }) => {
      const response = await fetch('/api/${k}', { signal })
      if (!response.ok) throw new Error(\`GET /api/${k}: \${response.status}\`)
      return ${c}Schema.array().parse(await response.json())
    }
  })
}
`,
      [`${dir}/${k}-page.tsx`]: `import { useSuspenseQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

import { ${c}QueryOptions } from './queries'

export function ${P}Page() {
  const { t } = useTranslation('${k}')
  const { data } = useSuspenseQuery(${c}QueryOptions())
  return (
    <main>
      <h1>{t('title')}</h1>
      <ul>
        {data.map((item) => (
          <li key={item.id}>{item.id}</li>
        ))}
      </ul>
    </main>
  )
}
`,
      [`${dir}/${k}-page.test.tsx`]: `import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { ${P}Page } from './${k}-page'
import { ${c}QueryOptions } from './queries'

describe('${P}Page', () => {
  it('lists what the query returned under its title', () => {
    const queryClient = new QueryClient()
    queryClient.setQueryData(${c}QueryOptions().queryKey, [{ id: 'first' }])
    render(
      <QueryClientProvider client={queryClient}>
        <${P}Page />
      </QueryClientProvider>
    )
    expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument()
    expect(screen.getByText('first')).toBeInTheDocument()
  })
})
`
    })
    next(genNext.feature(k))
  },

  component([name]) {
    if (!name) die(say.usageComponent)
    const k = kebab(name)
    const P = pascal(name)
    emit({
      [`src/components/${k}.tsx`]: `import type { ComponentProps } from 'react'

import { cn } from '@/lib/utils'

export function ${P}({ className, ...props }: ComponentProps<'div'>) {
  return <div className={cn(className)} {...props} />
}
`,
      [`src/components/${k}.test.tsx`]: `import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { ${P} } from './${k}'

describe('${P}', () => {
  it('renders its children', () => {
    render(<${P}>hello</${P}>)
    expect(screen.getByText('hello')).toBeInTheDocument()
  })
})
`
    })
  },

  hook([name]) {
    if (!name) die(say.usageHook)
    const k = kebab(name).replace(/^use-/, '')
    const P = pascal(k)
    emit({
      [`src/hooks/use-${k}.ts`]: `import { useState } from 'react'

export function use${P}(initial = false) {
  const [value, setValue] = useState(initial)
  return { value, setValue }
}
`,
      [`src/hooks/use-${k}.test.ts`]: `import { act, renderHook } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { use${P} } from './use-${k}'

describe('use${P}', () => {
  it('starts from the initial value and updates', () => {
    const { result } = renderHook(() => use${P}())
    expect(result.current.value).toBe(false)
    act(() => result.current.setValue(true))
    expect(result.current.value).toBe(true)
  })
})
`
    })
  },

  async host(_, { install: installing }) {
    const host = await hostScaffold()
    if (!host) {
      die(say.noHost)
    }
    const written = emit(host.files)
    if (!installing) {
      next(genNext.hostNoInstall, ...host.next)
      return
    }
    install(host.dependencies, [], host.devDependencies)
    format(written)
    next(genNext.check, ...host.next)
  },

  async app(_, { install: installing }) {
    if (workspace && !/^packages:/m.test(read('pnpm-workspace.yaml'))) {
      die(say.noWorkspace(appDir))
    }
    const { slug, name, description, nodeMajor, repo } = project()
    const quote = (text) => text.replaceAll('\\', '\\\\').replaceAll("'", "\\'")
    // Its files are written with the app's, so the first build already runs on the host.
    const host = (await hostScaffold()) ?? {
      files: {},
      dependencies: [],
      devDependencies: [],
      next: []
    }

    const manifest = (packageName, scripts) =>
      `${JSON.stringify({ name: packageName, private: true, type: 'module', scripts }, null, 2)}\n`
    const appScripts = {
      dev: 'vite',
      build: 'vite build',
      preview: 'vite preview',
      test: 'vitest',
      typecheck: 'tsc -b'
    }
    const repoScripts = {
      lint: 'eslint --max-warnings=0 .',
      format: "prettier --write '**/*.{js,mjs,cjs,jsx,ts,tsx,css,html}'",
      gen: 'node .devtools/scripts/gen.mjs'
    }
    const eslintConfig = (path, rules) => `import { defineConfig } from 'eslint/config'

import { ${rules} } from '${path}/.devtools/vite/eslint.js'

export default defineConfig([${rules}])
`
    const manifests = workspace
      ? {
          [join(appDir, 'package.json')]: manifest(
            `${slug}-${kebab(basename(appDir))}`,
            appScripts
          ),
          'package.json': manifest(slug, repoScripts),
          'eslint.config.js': eslintConfig('.', 'base')
        }
      : { 'package.json': manifest(slug, { ...appScripts, ...repoScripts }) }

    const written = emit(
      {
        ...host.files,
        'tsconfig.json': `{
  "files": [],
  "references": [{ "path": "./tsconfig.app.json" }, { "path": "./tsconfig.node.json" }],
  "compilerOptions": {
    "paths": { "@/*": ["./src/*"] }
  }
}
`,
        'tsconfig.app.json': `{
  "extends": "${repo}/.devtools/vite/tsconfig.base.json",
  "compilerOptions": {
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo",
    "lib": ["ES2023", "DOM", "DOM.Iterable"],
    "types": ["vite/client", "vitest/globals"],
    "jsx": "react-jsx",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src"]
}
`,
        'tsconfig.node.json': `{
  "extends": "${repo}/.devtools/vite/tsconfig.base.json",
  "compilerOptions": {
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.node.tsbuildinfo",
    "lib": ["ES2023"],
    "types": ["node"]
  },
  "include": ["vite.config.ts", "vitest.config.ts", "${join(repo, '.devtools/vite/*.ts')}", "${join(repo, '.devtools/host/*.ts')}"]
}
`,
        'vite.config.ts': `import { defineConfig } from 'vite'

import { app } from '${repo}/.devtools/vite/vite.ts'
import { site } from './src/config/site.ts'

// The hosting profile's plugin, if there is one, comes in through app().
export default defineConfig(await app({ site }))
`,
        'vitest.config.ts': `import { defineConfig } from 'vitest/config'

import { projects } from '${repo}/.devtools/vite/vitest.ts'

export default defineConfig({
  test: { projects: await projects() }
})
`,
        'eslint.config.js': eslintConfig(repo, 'app'),
        'index.html': `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="theme-color" content="%APP_THEME_COLOR%" />
    <title>%APP_TITLE%</title>
    <meta name="description" content="%APP_DESCRIPTION%" />
    <link rel="canonical" href="%APP_URL%" />
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="%APP_NAME%" />
    <meta property="og:title" content="%APP_TITLE%" />
    <meta property="og:description" content="%APP_DESCRIPTION%" />
    <meta property="og:url" content="%APP_URL%" />
    <meta property="og:image" content="%APP_OG_IMAGE%" />
    <meta property="og:locale" content="%APP_LOCALE%" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
`,
        'src/config/site.ts': `// The one source of truth for the site's metadata: index.html takes it at build time,
// and the app imports it for page titles.
export const site = {
  name: '${quote(name)}',
  title: '${quote(name)}',
  description: '${quote(description)}',
  url: 'https://${slug}.example.com',
  ogImage: '/og.png',
  themeColor: '#ffffff',
  locale: 'en_US'
} as const
`,
        'src/index.css': `@import 'tailwindcss';
`,
        'src/lib/utils.ts': `import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
`,
        'src/router.ts': `import type { QueryClient } from '@tanstack/react-query'
import { createRouter, type RouterHistory } from '@tanstack/react-router'

import { routeTree } from './routeTree.gen'

// TanStack Query owns freshness, so a preload always asks it rather than a router cache.
export function createAppRouter(queryClient: QueryClient, history?: RouterHistory) {
  return createRouter({
    routeTree,
    history,
    context: { queryClient },
    defaultPreload: 'intent',
    defaultPreloadStaleTime: 0,
    scrollRestoration: true
  })
}

declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof createAppRouter>
  }
}
`,
        'src/router.test.tsx': `import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createMemoryHistory, RouterProvider } from '@tanstack/react-router'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { createAppRouter } from './router'

describe('router', () => {
  it('renders the home page at /', async () => {
    const queryClient = new QueryClient()
    const router = createAppRouter(queryClient, createMemoryHistory({ initialEntries: ['/'] }))
    render(
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    )
    expect(await screen.findByRole('heading', { level: 1 })).toBeInTheDocument()
  })
})
`,
        'src/main.tsx': `import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import './i18n/config'
import { createAppRouter } from './router'
import './index.css'

const queryClient = new QueryClient()
const router = createAppRouter(queryClient)

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </StrictMode>
)
`,
        'src/routes/__root.tsx': `import type { QueryClient } from '@tanstack/react-query'
import { createRootRouteWithContext, Outlet } from '@tanstack/react-router'

export interface RouterContext {
  queryClient: QueryClient
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootLayout
})

function RootLayout() {
  return <Outlet />
}
`,
        'src/routes/index.tsx': `import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { site } from '@/config/site'

export const Route = createFileRoute('/')({
  component: HomeRoute
})

function HomeRoute() {
  const { t } = useTranslation()
  return (
    <main className="mx-auto max-w-2xl p-8">
      <h1 className="text-3xl font-semibold">{t('home.title', { name: site.name })}</h1>
      <p className="mt-2 text-neutral-600">{t('home.description')}</p>
    </main>
  )
}
`,
        'src/i18n/config.ts': `import i18n from 'i18next'
import LanguageDetector from 'i18next-browser-languagedetector'
import { initReactI18next } from 'react-i18next'

import { site } from '@/config/site'

type Catalog = Record<string, unknown>

// Every catalog in src/locales/<language>/<namespace>.json, so a new language or namespace
// is a new file and nothing here changes. They are small enough to bundle: no loading state.
// Cast rather than glob<Catalog>(: Vitest only knows not to cache a file whose glob results
// can change when it finds the text import.meta.glob( in it.
const catalogs = import.meta.glob('../locales/*/*.json', {
  eager: true,
  import: 'default'
}) as Record<string, Catalog>

export const resources: Record<string, Record<string, Catalog>> = {}
for (const [path, catalog] of Object.entries(catalogs)) {
  const [language, file] = path.split('/').slice(-2)
  resources[language] = { ...resources[language], [file.replace(/\\.json$/, '')]: catalog }
}

/** The language of site.locale. Its catalogs are the source the others are held to. */
export const defaultLanguage = site.locale.split('_')[0]

void i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources,
    fallbackLng: defaultLanguage,
    supportedLngs: Object.keys(resources),
    defaultNS: 'common',
    // React escapes what it renders.
    interpolation: { escapeValue: false },
    initAsync: false,
    detection: { order: ['querystring', 'localStorage', 'navigator'], caches: ['localStorage'] },
    // A key with no string is a bug: a test that renders it fails, the dev server warns.
    saveMissing: import.meta.env.DEV,
    missingKeyHandler: (_languages, namespace, key) => {
      const message = \`i18n: no string for \${namespace}:\${key}\`
      if (import.meta.env.MODE === 'test') throw new Error(message)
      console.warn(message)
    }
  })

// Screen readers pick their pronunciation from <html lang>, which index.html only starts.
const setLang = (language: string) => (document.documentElement.lang = language)
setLang(i18n.resolvedLanguage ?? defaultLanguage)
i18n.on('languageChanged', setLang)

export default i18n
`,
        'src/i18n/locales.test.ts': `import { describe, expect, it } from 'vitest'

import { defaultLanguage, resources } from './config'

const keys = (catalog: object, prefix = ''): string[] =>
  Object.entries(catalog)
    .flatMap(([key, value]) =>
      value && typeof value === 'object' ? keys(value, \`\${prefix}\${key}.\`) : [\`\${prefix}\${key}\`]
    )
    .sort()

describe('locales', () => {
  const source = resources[defaultLanguage]

  it(\`has catalogs for the default language, \${defaultLanguage}\`, () => {
    expect(source).toBeDefined()
  })

  const others = Object.keys(resources).filter((language) => language !== defaultLanguage)
  it.each(others)(\`%s has the namespaces and keys \${defaultLanguage} has, and no more\`, (language) => {
    expect(Object.keys(resources[language]).sort()).toEqual(Object.keys(source).sort())
    for (const namespace of Object.keys(source)) {
      expect(keys(resources[language][namespace] ?? {})).toEqual(keys(source[namespace]))
    }
  })
})
`,
        'src/locales/en/common.json': `${JSON.stringify(
          { home: { title: 'Welcome to {{name}}', description } },
          null,
          2
        )}\n`,
        'src/test/setup.ts': `import '@testing-library/jest-dom/vitest'
import '@/i18n/config'

// jsdom lays nothing out, so it has no scrollTo for the router's scroll restoration to call.
window.scrollTo = () => {}
`
      },
      {
        ...manifests,
        '.prettierignore': `# Generated, or vendored: shadcn/ui keeps its upstream formatting so updates diff cleanly.
${join(appDir, 'src/routeTree.gen.ts')}
${join(appDir, 'src/components/ui/')}
pnpm-lock.yaml
`,
        '.claude/launch.json': `{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "dev",
      "runtimeExecutable": "make",
      "runtimeArgs": ["-C", ".devtools", "dev"],
      "port": 5173
    }
  ]
}
`
      }
    )

    if (!installing) {
      next(genNext.appNoInstall(appDir))
      return
    }
    install(
      [
        'react',
        'react-dom',
        '@tanstack/react-router',
        '@tanstack/react-query',
        'zod',
        'clsx',
        'tailwind-merge',
        'i18next',
        'react-i18next',
        'i18next-browser-languagedetector',
        ...host.dependencies
      ],
      [
        '@types/react',
        '@types/react-dom',
        '@testing-library/react',
        '@testing-library/dom',
        '@testing-library/jest-dom',
        // The shadcn/ui CLI, so `pnpm exec shadcn` runs the version pnpm-lock.yaml pins.
        'shadcn'
      ],
      [
        'vite',
        '@vitejs/plugin-react',
        '@tanstack/router-plugin',
        'tailwindcss',
        '@tailwindcss/vite',
        // typescript-eslint supports TypeScript below 6.1.
        'typescript@~6.0.3',
        `@types/node@^${nodeMajor}`,
        'vitest',
        'jsdom',
        'eslint',
        '@eslint/js',
        'typescript-eslint',
        'globals',
        'eslint-plugin-react-hooks',
        'eslint-plugin-react-refresh',
        'eslint-plugin-jsx-a11y',
        '@tanstack/eslint-plugin-query',
        '@tanstack/eslint-plugin-router',
        'eslint-plugin-i18next',
        'prettier',
        ...host.devDependencies
      ]
    )
    // The first build writes src/routeTree.gen.ts, which the router and the types import.
    run('pnpm', ['exec', 'vite', 'build'])
    format(written)
    next(genNext.check, genNext.shadcn(appDir), genNext.commit, ...host.next)
  }
}

const { positionals, values } = parseArgs({
  allowPositionals: true,
  allowNegative: true,
  options: {
    feature: { type: 'string' },
    install: { type: 'boolean', default: true }
  }
})
const [kind, ...rest] = positionals
const generate = generators[kind]
if (!generate) die(say.usage(Object.keys(generators)))
await generate(rest, values)
