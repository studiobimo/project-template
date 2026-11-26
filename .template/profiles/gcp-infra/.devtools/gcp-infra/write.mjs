import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { basename, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { kebab } from '../scripts/slug.mjs'
import { deployEnvsOf } from './scaffold.mjs'

const SAY = {
  taken: (path) => `✖ ${path} exists: remove it first, this writes only what is not there`,
  wrote: (path) => `✔ wrote ${path}`,
  next: 'next:'
}

export const projectOf = (moduleUrl) => {
  const root = join(dirname(fileURLToPath(moduleUrl)), '..', '..')
  const makefile = readFileSync(join(root, '.devtools', 'Makefile'), 'utf8')
  return { root, slug: kebab(basename(root)), deployEnvs: deployEnvsOf(makefile) }
}

export const writeNew = (root, files, next) => {
  const taken = Object.keys(files).filter((path) => existsSync(join(root, path)))
  if (taken.length > 0) {
    for (const path of taken) console.error(SAY.taken(path))
    process.exit(1)
  }

  for (const [path, contents] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true })
    writeFileSync(join(root, path), contents)
    console.log(SAY.wrote(path))
  }
  console.log(SAY.next)
  for (const step of next) console.log(`  ${step}`)
}
