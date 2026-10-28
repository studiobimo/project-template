#!/usr/bin/env node
// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// Fails when one JavaScript chunk, or the client bundle as a whole, outgrows its budget.
// The budgets are tripwires for a runaway import, not performance targets: when a real
// feature needs more, raise the number in the same pull request so the growth is reviewed.
// The chunk limit is raw size, like Vite's own 500 KiB warning; the total is gzipped,
// which is closer to what a visitor downloads.
//
//   bundle-budget.mjs [--dir dist] [--chunk-kib 450] [--total-kib 550]
//
// Run it after the build. It reads every .js and .css file under --dir and changes nothing.
import { readdirSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { parseArgs } from 'node:util'
import { gzipSync } from 'node:zlib'

const { values } = parseArgs({
  options: {
    dir: { type: 'string', default: 'dist' },
    'chunk-kib': { type: 'string', default: '450' },
    'total-kib': { type: 'string', default: '550' }
  }
})
const KiB = 1024
const chunkLimit = Number(values['chunk-kib'])
const totalLimit = Number(values['total-kib'])

let files
try {
  files = readdirSync(values.dir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile() && /\.(js|css)$/.test(entry.name))
    .map((entry) => join(entry.parentPath, entry.name))
} catch {
  console.error(`✖ bundle budget: nothing built in ${values.dir}/. Build first.`)
  process.exit(1)
}
if (files.length === 0) {
  console.error(`✖ bundle budget: no .js or .css files in ${values.dir}/`)
  process.exit(1)
}

let total = 0
const problems = []
for (const file of files) {
  const bytes = readFileSync(file)
  total += gzipSync(bytes).length
  if (file.endsWith('.js') && bytes.length > chunkLimit * KiB) {
    problems.push(
      `${relative(values.dir, file)} is ${(bytes.length / KiB).toFixed(1)} KiB, over ` +
        `${chunkLimit} KiB: split it with a lazy route, lazy(), or a vendor chunk`
    )
  }
}
if (total > totalLimit * KiB) {
  problems.push(`the bundle is ${(total / KiB).toFixed(1)} KiB gzipped, over ${totalLimit} KiB`)
}

if (problems.length > 0) {
  for (const problem of problems) console.error(`✖ ${problem}`)
  process.exit(1)
}
console.log(
  `✔ bundle budget: ${(total / KiB).toFixed(1)} of ${totalLimit} KiB gzipped, ` +
    `every chunk under ${chunkLimit} KiB`
)
