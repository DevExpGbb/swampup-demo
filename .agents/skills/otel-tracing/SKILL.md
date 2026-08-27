---
name: otel-tracing
description: "Add OpenTelemetry distributed tracing to an HTTP service: create spans around request handlers, propagate trace context across service calls, and export over OTLP. Trigger when a service has no tracing, when spans are missing on a code path, or when someone asks to make a request traceable end to end."
license: MIT
metadata:
  author: "Daniel Meppiel"
  source: "SwampUp NYC keynote catalog"
---

# otel-tracing

Instrument an HTTP service with OpenTelemetry so every request produces a trace
you can follow across service boundaries. The goal is consistency: the same span
names, the same attributes, the same exporter wiring in every service.

## When to use this

- A service handles HTTP requests but produces no traces.
- A specific code path (a background job, an outbound call) is missing from the trace.
- You are standardizing tracing across several services and want them wired identically.

## When NOT to use this

- The service already has tracing and you only need to change the sampling rate — edit config, don't reinstrument.
- You need metrics or logs, not traces. This skill is spans-only.

## What it does

1. Adds the OpenTelemetry SDK and OTLP exporter dependency for the service's language.
2. Initializes a `TracerProvider` at startup with the service name as a resource attribute.
3. Wraps inbound request handling in a server span; wraps outbound calls in client spans.
4. Propagates W3C `traceparent` context on every outbound request.
5. Points the exporter at `OTEL_EXPORTER_OTLP_ENDPOINT` (defaults to `http://localhost:4317`).

## Span conventions

- **Name:** `HTTP <METHOD> <route-template>` (e.g. `HTTP GET /orders/{id}`) — never the raw URL, so cardinality stays bounded.
- **Required attributes:** `http.request.method`, `http.route`, `http.response.status_code`, `service.name`.
- **Errors:** set span status to `ERROR` and record the exception; never swallow it.

## Sampling

- Default to **parent-based** sampling so a trace is kept or dropped as a whole, never half-recorded.
- Set the head sample rate from `OTEL_TRACES_SAMPLER_ARG` (default `1.0` in dev, dial down in prod).
- Never sample on the raw URL or user id; sample on the trace, so linked spans stay together.

## Output

A minimal, reviewable diff: one startup/init file for the provider + exporter,
and thin wrappers at the request boundary. No business logic is changed.

## Verify

- Run the service, send one request, and confirm a trace appears at the OTLP endpoint (or in the console exporter during local dev).
- Confirm a downstream call shows up as a child span under the same trace ID.
