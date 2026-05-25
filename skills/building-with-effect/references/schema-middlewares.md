---
name: schema-middlewares
description: Intercept decoding with Schema.catchDecoding for fallbacks and service-based defaults. Use when handling missing or invalid data gracefully.
---

# Middlewares

A middleware wraps around the decoding or encoding process, letting you intercept errors, provide fallback values, or inject services.

## Table of Contents

- [Fallbacks](#fallbacks)
  - [Simple fallback value](#simple-fallback-value)
  - [Omitting a field when decoding fails](#omitting-a-field-when-decoding-fails)
- [Using a Service to provide a fallback value](#using-a-service-to-provide-a-fallback-value)

## Fallbacks

You can use `Schema.catchDecoding` to return a fallback value when decoding fails.

### Simple fallback value

**Example** (Returning a simple fallback value)

```ts
import { Effect, Schema } from "effect/unstable/schema"

// Provide a fallback string when decoding does not succeed
const schema = Schema.String.pipe(Schema.catchDecoding(() => Effect.succeedSome("b")))

console.log(String(Schema.decodeUnknownExit(schema)(null)))
// Success("b")
```

### Omitting a field when decoding fails

You can also return `Option.none()` to omit a field from the output.

**Example** (Omitting a field when decoding fails)

```ts
import { Effect, Schema } from "effect/unstable/schema"

// Omit the field when decoding does not succeed
const schema = Schema.Struct({
  a: Schema.optionalKey(Schema.String).pipe(Schema.catchDecoding(() => Effect.succeedNone))
})

console.log(String(Schema.decodeUnknownExit(schema)({ a: null })))
// Success({})
```

## Using a Service to provide a fallback value

You can use `Schema.catchDecodingWithContext` to get a fallback value from a service.

**Example** (Retrieving a fallback value from a service)

```ts
import { Effect, Option, Schema, Context } from "effect/unstable/schema"

// Define a service that provides a fallback value
class Service extends Context.Service<Service, { fallback: Effect.Effect<string> }>()("Service") {}

//      ┌─── Codec<string, string, Service, never>
//      ▼
const schema = Schema.revealCodec(
  Schema.String.pipe(
    Schema.catchDecodingWithContext(() =>
      Effect.gen(function*() {
        const service = yield* Service
        return Option.some(yield* service.fallback)
      })
    )
  )
)

// Provide the service during decoding
//      ┌─── Codec<string, string, never, never>
//      ▼
const provided = Schema.revealCodec(
  schema.pipe(Schema.middlewareDecoding(Effect.provideService(Service, { fallback: Effect.succeed("b") })))
)

console.log(String(Schema.decodeUnknownExit(provided)(null)))
// Success("b")
```

## See Also

- [schema-constructors.md](schema-constructors.md) - Default values in constructors
