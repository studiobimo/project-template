import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

import { graphOf } from './graph.ts'
import { WORKER } from './strings.ts'
import { workflows } from './workflows.ts'

const check = process.argv.includes('--check')
const directory = join(process.cwd(), '..', '..', WORKER.files.graphs)
let stale = false

mkdirSync(directory, { recursive: true })
for (const workflow of workflows()) {
  const path = join(directory, `${workflow.name}.json`)
  const contents = `${JSON.stringify(graphOf(workflow), null, 2)}\n`
  if (!check) {
    writeFileSync(path, contents)
    console.log(WORKER.messages.graphWritten(path))
  } else if (readFileSync(path, 'utf8') !== contents) {
    console.error(WORKER.messages.graphStale(path))
    stale = true
  }
}
process.exit(stale ? 1 : 0)
