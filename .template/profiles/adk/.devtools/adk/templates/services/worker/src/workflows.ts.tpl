import type { Workflow } from '@google/adk'

import { judgeModelName } from './models.ts'
import { buildTriage } from './triage.ts'

export const workflows = (): Workflow[] => [buildTriage(judgeModelName())]
