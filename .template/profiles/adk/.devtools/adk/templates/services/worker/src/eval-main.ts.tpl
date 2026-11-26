import { readFileSync } from 'node:fs'

import { evalCasesSchema } from '@scope/contracts'
import { startTelemetry, flushTelemetry } from '@scope/platform'

import { runEval, summarize } from './eval.ts'
import { judgeModelName, vertexModel } from './models.ts'
import { WORKER } from './strings.ts'
import { buildTriage } from './triage.ts'

startTelemetry('eval')

const cases = evalCasesSchema.parse(JSON.parse(readFileSync(WORKER.files.evalCases, 'utf8')))
const results = await runEval(cases, buildTriage(vertexModel(judgeModelName())))
for (const { line } of results) console.log(line)
console.log(summarize(results))
await flushTelemetry()
process.exit(results.every((result) => result.passed) ? 0 : 1)
