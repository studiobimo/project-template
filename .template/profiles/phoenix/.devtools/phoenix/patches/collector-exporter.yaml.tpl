  otlphttp/phoenix:
    endpoint: ${env:PHOENIX_URL}
    encoding: proto
    headers:
      Authorization: Bearer ${env:PHOENIX_API_KEY}
