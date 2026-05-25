---
name: schema-custom-types
description: Declare custom types with Schema.declare and Schema.declareConstructor. Use when defining schemas for types not covered by built-in combinators.
---

# Declaring Custom Types

When none of the built-in schema combinators fit your data type, use `Schema.declare` or `Schema.declareConstructor`.

## Table of Contents

- [Schema.declare (non-parametric types)](#schemadeclare-non-parametric-types)
- [Schema.declareConstructor (parametric types)](#schemadeclareconstructor-parametric-types)

## Schema.declare (non-parametric types)

`Schema.declare` creates a schema from a **type guard** — a function that checks whether an unknown value is of a given type. This is useful when you have a type that doesn't fit the built-in combinators (like `Struct`, `Array`, etc.) and you need to teach Schema how to recognize it.

```ts
Schema.declare<T>(
  is: (u: unknown) => u is T,
  annotations?: { expected?: string; toCodecJson?: ...; ... }
)
```

The first argument is your type guard. Schema will call it on any input value: if it returns `true`, decoding succeeds; if `false`, decoding fails.

**Example** (Creating a schema for `URL`)

```ts
import { Schema } from "effect/unstable/schema"

// The type guard tells Schema how to recognize a URL instance
const URLSchema = Schema.declare(
  (u): u is URL => u instanceof URL
)

console.log(String(Schema.decodeUnknownExit(URLSchema)(new URL("https://example.com"))))
// Success(https://example.com/)

console.log(String(Schema.decodeUnknownExit(URLSchema)(null)))
// Failure(Cause([Fail(SchemaError(Expected <Declaration>, got null))]))
```

> **Tip**: For simple `instanceof` checks, prefer `Schema.instanceOf(URL)`, it wraps `Schema.declare` with an `instanceof` guard automatically.

### Customizing the error message with `expected`

The default error message `Expected <Declaration>` is not very descriptive. Use the `expected` annotation (second argument) to provide a human-readable name for your type.

**Example** (Adding an `expected` annotation)

```ts
import { Schema } from "effect/unstable/schema"

const URLSchema = Schema.declare(
  (u): u is URL => u instanceof URL,
  { expected: "URL" }
)

console.log(String(Schema.decodeUnknownExit(URLSchema)(null)))
// Failure(Cause([Fail(SchemaError(Expected URL, got null))]))
```

### Adding JSON support with `toCodecJson`

`Schema.toCodecJson` derives a codec that can convert your type **to and from JSON**. By default, declared schemas have no JSON representation — encoding produces `null`.

**Example** (Making `URL` JSON-serializable)

```ts
import { Effect, Option, Schema, SchemaIssue, SchemaTransformation } from "effect/unstable/schema"

const URLSchema = Schema.declare(
  (u): u is URL => u instanceof URL,
  {
    expected: "URL",
    // Teach Schema how to convert URL <-> JSON
    toCodecJson: () =>
      Schema.link<globalThis.URL>()(
        // The JSON representation is a plain string
        Schema.String,
        // How to convert between URL and string
        SchemaTransformation.transformOrFail<URL, string>({
          // JSON string -> URL (may fail if the string is not a valid URL)
          decode: (s) =>
            Effect.try({
              try: () => new URL(s),
              catch: (e) => new SchemaIssue.InvalidValue(Option.some(s), { message: globalThis.String(e) })
            }),
          // URL -> JSON string (always succeeds)
          encode: (url) => Effect.succeed(url.href)
        })
      )
  }
)

const codec = Schema.toCodecJson(URLSchema)

// Now encoding produces the URL's href string
console.log(String(Schema.encodeUnknownExit(codec)(new URL("https://example.com"))))
// Success("https://example.com/")

// And decoding parses a string back into a URL
console.log(String(Schema.decodeUnknownExit(codec)("https://example.com")))
// Success(https://example.com/)
```

## Schema.declareConstructor (parametric types)

While `Schema.declare` works for fixed types like `URL` or `File`, some types are **generic** — they contain other types as parameters. Think of `Array<A>`, `Option<A>`, or a custom `Box<A>`. The schema for `Box<number>` is different from `Box<string>` because the inner value has a different type.

`Schema.declareConstructor` handles this by letting you define a **schema factory**: a function that takes schemas for the type parameters and returns a schema for the full type.

### How the two-step call works

`declareConstructor` uses a curried (two-step) call pattern:

```ts
Schema.declareConstructor<Type, Encoded>()(
  typeParameters, // array of schemas, one per type parameter
  run, // factory that produces the parsing function
  annotations // optional metadata (same as Schema.declare)
)
```

1. **Outer call** `declareConstructor<Type, Encoded>()` — fixes the TypeScript types
2. **Inner call** `(typeParameters, run, annotations)` — provides the runtime behavior

**Example** (A generic `Box<A>` container)

```ts
import { Effect, Option, Schema, SchemaIssue, SchemaParser } from "effect/unstable/schema"

// 1. Define the type
interface Box<A> {
  readonly value: A
}

// 2. A type guard that checks the shape (ignoring the inner type)
const isBox = (u: unknown): u is Box<unknown> => typeof u === "object" && u !== null && "value" in u

// 3. Create a schema factory
const Box = <A extends Schema.Top>(item: A) =>
  Schema.declareConstructor<Box<A["Type"]>, Box<A["Encoded"]>>()(
    [item],
    ([itemCodec]) =>
    (u, ast, options) => {
      if (!isBox(u)) {
        return Effect.fail(new SchemaIssue.InvalidType(ast, Option.some(u)))
      }
      return Effect.mapBothEager(
        SchemaParser.decodeUnknownEffect(itemCodec)(u.value, options),
        {
          onSuccess: (value) => ({ value }),
          onFailure: (issue) => new SchemaIssue.Pointer(["value"], issue)
        }
      )
    }
  )

// Use it: Box<number> that decodes strings to finite numbers
const schema = Box(Schema.FiniteFromString)

console.log(String(Schema.decodeUnknownExit(schema)({ value: "1" })))
// Success({ value: 1 })

console.log(String(Schema.decodeUnknownExit(schema)({ value: "a" })))
// Failure(Cause([Fail(SchemaError(Expected a finite number, got NaN
//   at ["value"]))]))
```

## See Also

- [schema-composite.md](schema-composite.md) - Using schemas in structs and arrays
- [schema-serialization.md](schema-serialization.md) - JSON serialization for custom types
