import { PubSub } from '@google-cloud/pubsub'
import { SpanKind } from '@opentelemetry/api'
import { parsePushEnvelope, type PushEnvelope } from '@scope/contracts'

import { TELEMETRY } from './strings.ts'
import { extractTraceContext, injectTraceContext, inSpan } from './telemetry.ts'

export interface Message {
  data: Uint8Array
  orderingKey: string
  attributes: Record<string, string>
}

export interface Publisher {
  publish(topic: string, message: Message): Promise<string>
}

export interface Topic<In, Out> {
  name: string
  encode(payload: In): Uint8Array
  decode(data: Uint8Array): Out
}

export class PubSubPublisher implements Publisher {
  private readonly client = new PubSub()
  private readonly topicSuffix: string

  constructor(topicSuffix = '') {
    this.topicSuffix = topicSuffix
  }

  async publish(topic: string, { data, orderingKey, attributes }: Message): Promise<string> {
    const target = this.client.topic(`${topic}${this.topicSuffix}`, { messageOrdering: true })
    try {
      return await target.publishMessage({ data: Buffer.from(data), orderingKey, attributes })
    } catch (error) {
      target.resumePublishing(orderingKey)
      throw error
    }
  }
}

export function publishTopic<In, Out>(
  publisher: Publisher,
  topic: Topic<In, Out>,
  payload: In,
  orderingKey: string
): Promise<string> {
  return inSpan(
    TELEMETRY.spans.publish(topic.name),
    (span) => {
      span.setAttributes({
        [TELEMETRY.attributes.system]: TELEMETRY.values.system,
        [TELEMETRY.attributes.topic]: topic.name,
        [TELEMETRY.attributes.orderingKey]: orderingKey
      })
      return publisher.publish(topic.name, {
        data: topic.encode(payload),
        orderingKey,
        attributes: injectTraceContext()
      })
    },
    { kind: SpanKind.PRODUCER }
  )
}

export function consumeTopic<In, Out, Result>(
  topic: Topic<In, Out>,
  body: string,
  handle: (payload: Out, envelope: PushEnvelope) => Promise<Result>
): Promise<Result> {
  const envelope = parsePushEnvelope(body)
  return inSpan(
    TELEMETRY.spans.process(topic.name),
    (span) => {
      span.setAttributes({
        [TELEMETRY.attributes.system]: TELEMETRY.values.system,
        [TELEMETRY.attributes.topic]: topic.name,
        [TELEMETRY.attributes.messageId]: envelope.message.messageId
      })
      return handle(topic.decode(Buffer.from(envelope.message.data, 'base64')), envelope)
    },
    { kind: SpanKind.CONSUMER },
    extractTraceContext(envelope.message.attributes)
  )
}
