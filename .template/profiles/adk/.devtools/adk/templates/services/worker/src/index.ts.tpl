import { serve, startTelemetry } from '@scope/platform'

import { createWorker } from './app.ts'
import { judgeModelName, vertexModel } from './models.ts'

startTelemetry('worker')

serve(createWorker({ judge: vertexModel(judgeModelName()) }))
