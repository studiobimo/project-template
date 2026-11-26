export const GLYPH = { ok: '✔', fail: '✖' }

export const SCAFFOLD = {
  refusing: (paths) => `refusing to overwrite: ${paths.join(', ')}`,
  created: (path) => `  created ${path}`,
  patched: (path) => `  patched ${path}`,
  anchorMissing: (path, anchor) => `${path} no longer has ${JSON.stringify(anchor)}: patch it by hand`,
  running: (command, args) => `\n$ ${command} ${args.join(' ')}`,
  failed: (command, args) => `${command} ${args[0]} failed`,
  next: (lines) => `\nNext:\n${lines.map((line) => `  ${line}`).join('\n')}`
}

export const GEN = {
  dirs: { services: 'services', contracts: 'packages/contracts' },
  commands: { devtools: 'make -C .devtools', gen: 'node .devtools/typescript/gen.mjs' }
}

export const MESSAGES = {
  gen: {
    usage: (kinds) => `usage: gen.mjs <${kinds.join('|')}> ...`,
    usageService: 'usage: gen.mjs service <name>',
    usagePackage: 'usage: gen.mjs package <name>',
    noWorkspace: `no ${GEN.dirs.contracts}: run ${GEN.commands.gen} workspace first`
  },
  next: {
    service: `add a service: ${GEN.commands.gen} service <name>`,
    image: (name) =>
      `build its image: ${GEN.commands.devtools} image SERVICE=${GEN.dirs.services}/${name}`,
    check: `${GEN.commands.devtools} check`,
    commit: 'git add -A                     # pnpm-lock.yaml included'
  }
}
