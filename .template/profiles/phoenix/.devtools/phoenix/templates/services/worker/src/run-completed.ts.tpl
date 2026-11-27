import { trace } from '@opentelemetry/api'
import {
  orderingKeyOf,
  runCompleted,
  type PrEvent,
  type TriageVerdict
} from '@scope/contracts'
import { publishTopic, type Publisher } from '@scope/platform'

export const publishRunCompleted =
  (publisher: Publisher) =>
  async (event: PrEvent, verdict: TriageVerdict): Promise<void> => {
    const context = trace.getActiveSpan()?.spanContext()
    if (!context) return
    await publishTopic(
      publisher,
      runCompleted,
      { event, verdict, traceId: context.traceId, spanId: context.spanId },
      orderingKeyOf(event)
    )
  }
