import { serve, startTelemetry } from '@scope/platform'

import { createWorker } from './app.ts'
import { judgeModelName, vertexModel } from './models.ts'
import { sessionService } from './sessions.ts'

startTelemetry('worker')

const sessions = await sessionService()

serve(createWorker({ judge: vertexModel(judgeModelName()), sessions }))
