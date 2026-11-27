import type { Message, Publisher } from './bus.ts'
import type { Reply } from './http.ts'
import { BUS } from './strings.ts'

export type Subscriber = (body: string) => Promise<Reply>

export interface Delivery {
  topic: string
  reply: Reply
}

export class MemoryBus implements Publisher {
  readonly deliveries: Delivery[] = []
  readonly deadLetters: Message[] = []
  private readonly subscribers = new Map<string, Subscriber>()
  private readonly chains = new Map<string, Promise<void>>()
  private count = 0

  subscribe(topic: string, subscriber: Subscriber): void {
    this.subscribers.set(topic, subscriber)
  }

  async publish(topic: string, message: Message): Promise<string> {
    const messageId = String(++this.count)
    const previous = this.chains.get(message.orderingKey) ?? Promise.resolve()
    this.chains.set(
      message.orderingKey,
      previous.then(() => this.deliver(topic, message, messageId))
    )
    return messageId
  }

  async idle(): Promise<void> {
    await Promise.all(this.chains.values())
  }

  private async deliver(topic: string, message: Message, messageId: string): Promise<void> {
    const subscriber = this.subscribers.get(topic)
    if (!subscriber) return
    const body = JSON.stringify({
      message: {
        data: Buffer.from(message.data).toString('base64'),
        messageId,
        orderingKey: message.orderingKey,
        attributes: message.attributes
      },
      subscription: `${topic}-push`
    })
    for (let attempt = 1; attempt <= BUS.maxAttempts; attempt++) {
      const reply = await subscriber(body)
      this.deliveries.push({ topic, reply })
      if (reply.status >= 200 && reply.status < 300) return
    }
    this.deadLetters.push(message)
  }
}
