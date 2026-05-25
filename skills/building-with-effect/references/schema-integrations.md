---
name: schema-integrations
description: Working examples for TanStack Form and Elysia integration with Effect Schema.
---

# Integrations

Schema integrates with popular frameworks and libraries.

## Table of Contents

- [TanStack Form](#tanstack-form)
  - [Features](#features)
  - [Example](#example)
- [Elysia](#elysia)

## TanStack Form

### Features

- Errors are formatted with the `StandardSchemaV1` formatter
- Fields are validated **and parsed** (not just strings)
- You can add form-level validation by attaching filters to the struct
- Schemas may include async transformations

### Example (Parse user input and surface form-level errors)

```tsx
import { useForm } from "@tanstack/react-form"
import type { AnyFieldApi } from "@tanstack/react-form"
import { Effect, Schema, SchemaGetter, SchemaTransformation } from "effect/unstable/schema"
import React from "react"

// ----------------------------------------------------
// Toolkit
// ----------------------------------------------------

const UndefinedFromEmptyString = Schema.Undefined.pipe(
  Schema.encodeTo(Schema.Literal(""), {
    decode: SchemaGetter.transform(() => undefined),
    encode: SchemaGetter.transform(() => "" as const
  })
)

function optional<S extends Schema.Top>(schema: S) {
  return Schema.Union([UndefinedFromEmptyString, schema])
}

function decode<T, E>(schema: Schema.Codec<T, E>) {
  return function(value: unknown) {
    return Schema.decodeUnknownEffect(schema)(value).pipe(
      Effect.mapError((error) => error.message),
      Effect.result,
      Effect.runPromise
    )
  }
}

// ----------------------------------------------------
// Schemas
// ----------------------------------------------------

const FirstName = Schema.String.check(
  Schema.isMinLength(3, { message: "must be at least 3 characters" })
)
const Age = Schema.Number.check(
  Schema.isInt({ message: "must be an integer" }).abort(),
  Schema.isBetween({ minimum: 18, maximum: 100 }, { message: "must be between 18 and 100" })
).pipe(Schema.encodeTo(Schema.String, SchemaTransformation.numberFromString))

const schema = Schema.Struct({
  firstName: FirstName,
  age: optional(Age)
}).check(
  Schema.makeFilter(({ firstName, age }) => {
    if (firstName === "John" && age === undefined) return "Age is required for John"
  })
)

function FieldInfo({ field }: { field: AnyFieldApi }) {
  return (
    <>
      {field.state.meta.isTouched && !field.state.meta.isValid ?
        <em>{field.state.meta.errors.map((error) => error.message).join(", ")}</em> :
        null}
    </>
  )
}

export default function App() {
  const parsedRef = React.useRef<undefined | typeof schema.Type>(undefined)

  const form = useForm({
    defaultValues: { firstName: "John", age: "" },
    validators: {
      onChangeAsync: Schema.toStandardSchemaV1(schema),
      onSubmitAsync: async ({ value }) => {
        const r = await decode(schema)(value)
        if (r._tag === "Failure") return r.failure
        parsedRef.current = r.success
      }
    },
    onSubmit: async () => {
      const parsed = parsedRef.current
      if (!parsed) throw new Error("Unexpected submit without parsed data")
      console.log(parsed)
    }
  })

  return (
    <div>
      <form.Field name="firstName">
        {(field) => (
          <>
            <label>{field.name}</label>
            <input value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} />
            <FieldInfo field={field} />
          </>
        )}
      </form.Field>
      <form.Field name="age">
        {(field) => (
          <>
            <label>{field.name}</label>
            <input value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} />
            <FieldInfo field={field} />
          </>
        )}
      </form.Field>
      <button type="submit">Submit</button>
    </div>
  )
}
```

## Elysia

```ts
import { node } from "@elysiajs/node"
import { openapi } from "@elysiajs/openapi"
import { Schema } from "effect/unstable/schema"
import { Elysia } from "elysia"

function encodingJsonSchema<T, E, RD>(schema: Schema.Codec<T, E, RD, never>) {
  return Schema.toStandardSchemaV1(
    Schema.flip(Schema.toCodecJson(schema)).annotate({
      direction: "encoding"
    })
  )
}

function decodingJsonSchema<T, E, RE>(schema: Schema.Codec<T, E, never, RE>) {
  return Schema.toStandardSchemaV1(Schema.toCodecJson(schema))
}

function decodingStringSchema<T, E, RE>(schema: Schema.Codec<T, E, never, RE>) {
  return Schema.toStandardSchemaV1(Schema.toCodecStringTree(schema))
}

function mapJsonSchema(schema: Schema.Top) {
  return Schema.toJsonSchema(schema.ast.annotations?.direction === "encoding" ? Schema.flip(schema) : schema, {
    target: "draft-2020-12",
    referenceStrategy: "skip"
  }).schema
}

new Elysia({ adapter: node() })
  .use(openapi({ mapJsonSchema: { effect: mapJsonSchema } }))
  .get("/id/:id", ({ params }) => params.id, {
    response: {
      200: decodingStringSchema(Schema.String),
      400: decodingJsonSchema(Schema.String)
    }
  })
  .listen(3000)
```

## See Also

- [schema-serialization.md](schema-serialization.md) - Serialization formats
- [error-handling.md](../error-handling.md) - Error handling patterns
