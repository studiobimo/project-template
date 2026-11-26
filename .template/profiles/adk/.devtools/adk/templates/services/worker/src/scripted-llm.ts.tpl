import {
  BaseLlm,
  type BaseLlmConnection,
  type LlmRequest,
  type LlmResponse
} from '@google/adk'

export class ScriptedLlm extends BaseLlm {
  readonly requests: LlmRequest[] = []

  private readonly answer: (request: LlmRequest) => string

  constructor(answer: (request: LlmRequest) => string) {
    super({ model: 'scripted' })
    this.answer = answer
  }

  async *generateContentAsync(request: LlmRequest): AsyncGenerator<LlmResponse, void> {
    this.requests.push(request)
    yield { content: { role: 'model', parts: [{ text: this.answer(request) }] } }
  }

  connect(): Promise<BaseLlmConnection> {
    return Promise.reject(new Error('scripted models are not live'))
  }
}
