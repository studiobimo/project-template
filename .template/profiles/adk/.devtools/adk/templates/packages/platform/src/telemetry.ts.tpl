import { maybeSetOtelProviders, type OTelHooks } from '@google/adk'
import {
  context,
  propagation,
  ROOT_CONTEXT,
  SpanStatusCode,
  trace,
  type Context,
  type Span,
  type SpanOptions
} from '@opentelemetry/api'
import { W3CTraceContextPropagator } from '@opentelemetry/core'

import { TELEMETRY } from './strings.ts'

export function startTelemetry(serviceName: string, hooks: OTelHooks[] = []): void {
  process.env.OTEL_SERVICE_NAME ??= serviceName
  maybeSetOtelProviders(hooks)
  propagation.setGlobalPropagator(new W3CTraceContextPropagator())
}

export async function flushTelemetry(): Promise<void> {
  const provider = trace.getTracerProvider() as { getDelegate?: () => unknown }
  const delegate = provider.getDelegate?.() as { forceFlush?: () => Promise<void> } | undefined
  await delegate?.forceFlush?.()
}

export function inSpan<T>(
  name: string,
  work: (span: Span) => Promise<T> | T,
  options: SpanOptions = {},
  parent: Context = context.active()
): Promise<T> {
  return trace
    .getTracer(TELEMETRY.tracer)
    .startActiveSpan(name, options, parent, async (span) => {
      try {
        return await work(span)
      } catch (error) {
        span.recordException(error instanceof Error ? error : String(error))
        span.setStatus({ code: SpanStatusCode.ERROR })
        throw error
      } finally {
        span.end()
      }
    })
}

export function injectTraceContext(
  attributes: Record<string, string> = {}
): Record<string, string> {
  propagation.inject(context.active(), attributes)
  return attributes
}

export const extractTraceContext = (attributes: Record<string, string> = {}): Context =>
  propagation.extract(ROOT_CONTEXT, attributes)
