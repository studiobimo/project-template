#!/usr/bin/env node
import { readdirSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { parseArgs } from 'node:util'
import { gzipSync } from 'node:zlib'

import { budgetMessages as say, glyph } from './strings.mjs'

const { values } = parseArgs({
  options: {
    dir: { type: 'string', default: 'dist' },
    'chunk-kib': { type: 'string', default: '450' },
    'total-kib': { type: 'string', default: '550' }
  }
})
const KiB = 1024
const kib = (bytes) => (bytes / KiB).toFixed(1)
const chunkLimit = Number(values['chunk-kib'])
const totalLimit = Number(values['total-kib'])

let files
try {
  files = readdirSync(values.dir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile() && /\.(js|css)$/.test(entry.name))
    .map((entry) => join(entry.parentPath, entry.name))
} catch {
  console.error(`${glyph.fail} ${say.nothingBuilt(values.dir)}`)
  process.exit(1)
}
if (files.length === 0) {
  console.error(`${glyph.fail} ${say.noFiles(values.dir)}`)
  process.exit(1)
}

let total = 0
const problems = []
for (const file of files) {
  const bytes = readFileSync(file)
  total += gzipSync(bytes).length
  if (file.endsWith('.js') && bytes.length > chunkLimit * KiB) {
    problems.push(say.chunkOver(relative(values.dir, file), kib(bytes.length), chunkLimit))
  }
}
if (total > totalLimit * KiB) {
  problems.push(say.totalOver(kib(total), totalLimit))
}

if (problems.length > 0) {
  for (const problem of problems) console.error(`${glyph.fail} ${problem}`)
  process.exit(1)
}
console.log(`${glyph.ok} ${say.within(kib(total), totalLimit, chunkLimit)}`)
