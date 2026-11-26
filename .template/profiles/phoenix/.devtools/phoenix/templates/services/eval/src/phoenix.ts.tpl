import type { RunScore } from '@scope/contracts'

import { EVAL } from './strings.ts'

export interface PhoenixConfig {
  url: string
  apiKey: string
  fetch?: typeof fetch
}

export async function annotateSpan(
  { url, apiKey, fetch: send = fetch }: PhoenixConfig,
  spanId: string,
  result: RunScore
): Promise<void> {
  const response = await send(`${url}${EVAL.phoenix.annotationsPath}`, {
    method: 'POST',
    headers: { 'content-type': EVAL.phoenix.json, authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      data: [
        {
          name: EVAL.phoenix.annotationName,
          annotator_kind: EVAL.phoenix.annotatorKind,
          span_id: spanId,
          result,
          identifier: ''
        }
      ]
    })
  })
  const type = response.headers.get('content-type') ?? ''
  if (!response.ok || !type.includes(EVAL.phoenix.json)) {
    throw new Error(EVAL.messages.phoenixRefused(response.status, type))
  }
}
