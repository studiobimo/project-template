// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// Every message the profile's scripts print, gen.mjs and bundle-budget.mjs, in one place: the
// Node half of what .devtools/scripts/strings.sh is to the shell scripts. A message that
// names a value is a function of it, so the value is always an argument.
//
// The text of the files gen.mjs writes is not here. Those are templates of code, and a
// generated app's own strings start in its src/locales/ catalogs.

export const glyph = { ok: '✔', fail: '✖' }
export const devtools = 'make -C .devtools'
export const gen = 'node .devtools/scripts/gen.mjs'

const pnpmIn = (appDir) => (appDir === '.' ? 'pnpm' : `pnpm --dir ${appDir}`)

export const genMessages = {
  usage: (kinds) => `usage: gen.mjs <${kinds.join('|')}> ...`,
  usageRoute: 'usage: gen.mjs route <path> [--feature <name>]',
  usageFeature: 'usage: gen.mjs feature <name>',
  usageComponent: 'usage: gen.mjs component <name>',
  usageHook: 'usage: gen.mjs hook <name>',
  refusing: (paths) => `refusing to overwrite: ${paths.join(', ')}`,
  created: (path) => `  created ${path}`,
  running: (command, args) => `\n$ ${command} ${args.join(' ')}`,
  failed: (command, args) => `${command} ${args[0]} failed`,
  next: (lines) => `\nNext:\n${lines.map((line) => `  ${line}`).join('\n')}`,
  routeNoSlash: (path) => `a route path starts with /: ${path}`,
  routeBadSegment: (segment, path) => `not a route path segment: '${segment}' in ${path}`,
  noFeature: (name) => `no feature ${name}: run gen.mjs feature ${name} first`,
  noHost: `no hosting profile: list one in .template-profiles, then ${devtools} sync`,
  noWorkspace: (appDir) =>
    `APP_DIR is ${appDir}: list it under packages: at the top of pnpm-workspace.yaml first`
}

// What to do after each generator, one line per step.
export const genNext = {
  route: 'the router plugin adds it to src/routeTree.gen.ts on the next dev or build run',
  feature: (name) => `route it: ${gen} route /${name} --feature ${name}`,
  hostNoInstall: 'install the packages .devtools/host/scaffold.mjs lists',
  appNoInstall: (appDir) =>
    `install the packages listed in .devtools/scripts/gen.mjs (app), then: ${pnpmIn(appDir)} exec vite build`,
  check: `${devtools} check`,
  shadcn: (appDir) =>
    `${pnpmIn(appDir)} exec shadcn init          # the design tokens and components.json, for shadcn/ui`,
  commit: 'git add -A                     # src/routeTree.gen.ts and pnpm-lock.yaml included'
}

export const budgetMessages = {
  nothingBuilt: (dir) => `bundle budget: nothing built in ${dir}/. Build first.`,
  noFiles: (dir) => `bundle budget: no .js or .css files in ${dir}/`,
  chunkOver: (file, kib, limit) =>
    `${file} is ${kib} KiB, over ${limit} KiB: split it with a lazy route, lazy(), or a vendor chunk`,
  totalOver: (kib, limit) => `the bundle is ${kib} KiB gzipped, over ${limit} KiB`,
  within: (kib, total, chunk) =>
    `bundle budget: ${kib} of ${total} KiB gzipped, every chunk under ${chunk} KiB`
}
