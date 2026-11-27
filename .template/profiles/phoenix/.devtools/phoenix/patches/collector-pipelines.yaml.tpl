    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection/gcp, transform/attributes, batch]
      exporters: [otlphttp/gcp]
    traces/phoenix:
      receivers: [otlp]
      processors: [memory_limiter, resource/phoenix, batch]
      exporters: [otlphttp/phoenix]
