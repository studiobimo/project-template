  transform/attributes:
    error_mode: ignore
    trace_statements:
      - context: span
        statements: &content
__STRIP__
      - context: spanevent
        statements: *content
  resource/phoenix:
    attributes:
      - key: openinference.project.name
        value: __PROJECT__
        action: upsert
