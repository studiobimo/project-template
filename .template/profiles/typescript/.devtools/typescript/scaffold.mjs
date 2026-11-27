import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'

import { GLYPH, SCAFFOLD } from './strings.mjs'

export const die = (message) => {
  console.error(`${GLYPH.fail} ${message}`)
  process.exit(1)
}

export function writeNew(root, files) {
  const taken = Object.keys(files).filter((path) => existsSync(join(root, path)))
  if (taken.length > 0) die(SCAFFOLD.refusing(taken))
  for (const [path, contents] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true })
    writeFileSync(join(root, path), contents)
    console.log(SCAFFOLD.created(path))
  }
  return Object.keys(files)
}

export function run(command, args, cwd) {
  console.log(SCAFFOLD.running(command, args))
  const { status, error } = spawnSync(command, args, { cwd, stdio: 'inherit' })
  if (error || status !== 0) die(SCAFFOLD.failed(command, args))
}

export const printNext = (...lines) => console.log(SCAFFOLD.next(lines))

export const missingAnchor = (text, edits) => edits.find(({ from }) => !text.includes(from))?.from

export function inRoot(root) {
  const read = (path) => (existsSync(join(root, path)) ? readFileSync(join(root, path), 'utf8') : '')
  return {
    read,
    run: (command, args) => run(command, args, root),
    emit: (files) => writeNew(root, files),
    patch(path, edits) {
      const text = read(path)
      const anchor = missingAnchor(text, edits)
      if (anchor !== undefined) die(SCAFFOLD.anchorMissing(path, anchor))
      writeFileSync(
        join(root, path),
        edits.reduce((current, { from, to }) => current.replace(from, () => to), text)
      )
      console.log(SCAFFOLD.patched(path))
    }
  }
}
