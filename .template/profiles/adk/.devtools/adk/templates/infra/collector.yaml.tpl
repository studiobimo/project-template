extensions:
  googleclientauth:
  health_check:
    endpoint: 0.0.0.0:13133

receivers:
  otlp:
    protocols:
      http:
        endpoint: localhost:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 80
    spike_limit_percentage: 25
  resourcedetection/gcp:
    detectors: [env, gcp]
    timeout: 10s
  batch:
    send_batch_size: 200
    timeout: 1s

exporters:
  otlphttp/gcp:
    endpoint: https://telemetry.googleapis.com
    encoding: proto
    auth:
      authenticator: googleclientauth

service:
  extensions: [health_check, googleclientauth]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection/gcp, batch]
      exporters: [otlphttp/gcp]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection/gcp, batch]
      exporters: [otlphttp/gcp]
