import { InMemorySessionService, type BaseSessionService } from '@google/adk'

export const sessionService = async (): Promise<BaseSessionService> => new InMemorySessionService()
