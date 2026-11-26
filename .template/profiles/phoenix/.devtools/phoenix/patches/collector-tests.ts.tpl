  it('sends traces to Phoenix with the API key, in a pipeline of their own', () => {
    const exporter = config.exporters['otlphttp/phoenix']
    expect(exporter?.endpoint).toBe('${env:PHOENIX_URL}')
    expect(exporter?.headers?.Authorization).toBe('Bearer ${env:PHOENIX_API_KEY}')
    expect(config.service.pipelines['traces/phoenix']?.exporters).toEqual(['otlphttp/phoenix'])
    expect(config.service.pipelines.traces?.exporters).not.toContain('otlphttp/phoenix')
  })

  it('keeps prompts and responses out of Cloud Trace, and only out of it', () => {
    const strip = 'transform/attributes'
    expect(config.service.pipelines.traces?.processors).toContain(strip)
    expect(config.service.pipelines['traces/phoenix']?.processors).not.toContain(strip)
    const statementsFor = (context: string) =>
      (config.processors[strip]?.trace_statements ?? [])
        .filter((group) => group.context === context)
        .flatMap((group) => group.statements)
    for (const context of ['span', 'spanevent']) {
      for (const attribute of [
        'gen_ai.input.messages',
        'gen_ai.output.messages',
        'gen_ai.system_instructions',
        'gen_ai.tool.call.arguments',
        'gen_ai.tool.call.result',
        'gen_ai.tool.definitions'
      ]) {
        expect(statementsFor(context)).toContain(`delete_key(attributes, "${attribute}")`)
      }
    }
  })
