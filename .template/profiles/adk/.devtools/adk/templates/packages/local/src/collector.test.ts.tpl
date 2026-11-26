import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'
import { parse } from 'yaml'

import { LOCAL } from './strings.ts'

interface Collector {
  extensions: Record<string, unknown>
  receivers: Record<string, unknown>
  processors: Record<string, unknown>
  exporters: Record<string, { endpoint?: string; auth?: { authenticator: string } }>
  service: {
    extensions: string[]
    pipelines: Record<string, { receivers: string[]; processors: string[]; exporters: string[] }>
  }
}

const config = parse(readFileSync(LOCAL.files.collector, 'utf8')) as Collector

describe('the collector config', () => {
  it('only names components it defines', () => {
    for (const name of config.service.extensions) expect(config.extensions).toHaveProperty(name)
    for (const pipeline of Object.values(config.service.pipelines)) {
      for (const name of pipeline.receivers) expect(config.receivers).toHaveProperty(name)
      for (const name of pipeline.processors) expect(config.processors).toHaveProperty(name)
      for (const name of pipeline.exporters) expect(config.exporters).toHaveProperty(name)
    }
  })

  it('exports traces to the Telemetry API with the service account credentials', () => {
    const exporter = config.exporters['otlphttp/gcp']
    expect(exporter?.endpoint).toBe('https://telemetry.googleapis.com')
    expect(exporter?.auth?.authenticator).toBe('googleclientauth')
    expect(config.service.pipelines.traces?.exporters).toContain('otlphttp/gcp')
  })

  it('listens on the port the services export to, on the loopback only', () => {
    expect(JSON.stringify(config.receivers)).toContain('localhost:4318')
  })
})
