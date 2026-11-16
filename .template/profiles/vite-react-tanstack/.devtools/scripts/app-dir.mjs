import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

export const readFromRoot = (root, path) =>
  existsSync(join(root, path)) ? readFileSync(join(root, path), 'utf8') : ''

export const appDirOf = (root) =>
  readFromRoot(root, '.devtools/Makefile').match(/^(?:APP_DIR|APPS)\s*[:?]?=\s*(\S+)/m)?.[1] ?? '.'
