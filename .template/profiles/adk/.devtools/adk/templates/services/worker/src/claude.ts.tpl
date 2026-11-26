import { AnthropicVertex } from '@anthropic-ai/vertex-sdk'
import {
  BaseLlm,
  type BaseLlmConnection,
  type LlmRequest,
  type LlmResponse
} from '@google/adk'

import { WORKER } from './strings.ts'

export interface ClaudeClient {
  messages: {
    create(params: {
      model: string
      max_tokens: number
      system?: string
      messages: Array<{ role: 'user' | 'assistant'; content: string }>
    }): Promise<{ content: Array<{ type: string; text?: string }> }>
  }
}

export interface VertexClaudeParams {
  model: string
  project?: string
  location?: string
  client?: ClaudeClient
}

const textOf = (parts: Array<{ text?: string }> = []) =>
  parts.map((part) => part.text ?? '').join('')

function systemPrompt(request: LlmRequest): string | undefined {
  const instruction = request.config?.systemInstruction
  const base =
    typeof instruction === 'string'
      ? instruction
      : instruction && typeof instruction === 'object' && 'parts' in instruction
        ? textOf(instruction.parts)
        : ''
  const schema = request.config?.responseJsonSchema ?? request.config?.responseSchema
  const lines = [base, schema ? WORKER.messages.claudeSchema(JSON.stringify(schema)) : '']
  return lines.filter(Boolean).join('\n\n') || undefined
}

export class VertexClaude extends BaseLlm {
  static override readonly supportedModels = [new RegExp(`^${WORKER.models.claudePrefix}-.*`)]

  private readonly client: ClaudeClient

  constructor({ model, project, location, client }: VertexClaudeParams) {
    super({ model })
    this.client =
      client ??
      (new AnthropicVertex({
        projectId: project,
        region: location ?? WORKER.models.defaultClaudeLocation
      }) as unknown as ClaudeClient)
  }

  async *generateContentAsync(request: LlmRequest): AsyncGenerator<LlmResponse, void> {
    const response = await this.client.messages.create({
      model: this.model,
      max_tokens: WORKER.models.maxTokens,
      system: systemPrompt(request),
      messages: request.contents.map((content) => ({
        role: content.role === 'model' ? 'assistant' : 'user',
        content: textOf(content.parts)
      }))
    })
    const text = response.content.map((block) => block.text ?? '').join('')
    if (!text) throw new Error(WORKER.messages.claudeNoText)
    yield { content: { role: 'model', parts: [{ text }] } }
  }

  connect(): Promise<BaseLlmConnection> {
    return Promise.reject(new Error(WORKER.messages.claudeLive))
  }
}
