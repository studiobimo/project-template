import type { Workflow } from '@google/adk'
import type { EvalCase } from '@scope/contracts'

import { WORKER } from './strings.ts'
import { runTriage } from './triage.ts'

export interface EvalResult {
  name: string
  passed: boolean
  line: string
}

export async function runEval(cases: EvalCase[], workflow: Workflow): Promise<EvalResult[]> {
  const results: EvalResult[] = []
  for (const { name, event, expect } of cases) {
    const { verdict } = await runTriage(workflow, event)
    const passed = verdict === expect.verdict
    results.push({
      name,
      passed,
      line: passed
        ? WORKER.messages.evalPassed(name)
        : WORKER.messages.evalFailed(name, expect.verdict, verdict)
    })
  }
  return results
}

export const summarize = (results: EvalResult[]) =>
  WORKER.messages.evalSummary(results.filter((result) => result.passed).length, results.length)
