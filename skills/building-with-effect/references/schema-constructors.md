---
name: schema-constructors
description: Create validated values with make and defaults. Use when constructing schema values at runtime with Effect Schema.
---

# Constructors

A constructor creates a value of the schema's type, running all validations at the time of creation.

## Table of Contents

- [make](#makeunsafe)
- [makeOption](#makeoption)
- [Constructors in Composed Schemas](#constructors-in-composed-schemas)
- [Branded Constructors](#branded-constructors)
- [Refined Constructors](#refined-constructors)
- [Default Values in Constructors](#default-values-in-constructors)
- [Effectful Defaults](#effectful-defaults)

## make

Every schema exposes a `make` method for creating values. If the value does not satisfy the schema, the constructor throws an error.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.Number.check(Schema.isGreaterThan(0))
})

// Create a value - throws if invalid
const value = schema.make({ a: 1 })
```

## makeOption

For a non-throwing alternative, use `Schema.makeOption` (or `SchemaParser.makeOption`), which returns `Option.Some` on success and `Option.None` on failure.

```ts
import { Schema, SchemaParser } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.Number.check(Schema.isGreaterThan(0))
})

console.log(schema.makeOption({ a: 1 }))
// { _id: 'Option', _tag: 'Some', value: { a: 1 } }

console.log(schema.makeOption({ a: -1 }))
// { _id: 'Option', _tag: 'None' }

// Equivalent standalone usage:
const parse = SchemaParser.makeOption(schema)
console.log(parse({ a: 1 }))
// { _id: 'Option', _tag: 'Some', value: { a: 1 } }
```

## Constructors in Composed Schemas

To support constructing values from composed schemas, `make` is now available on all schemas, including unions.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Union([Schema.Struct({ a: Schema.String }), Schema.Struct({ b: Schema.Number })])

schema.make({ a: "hello" })
schema.make({ b: 1 })
```

## Branded Constructors

Branding adds an invisible marker to a type so that values from different domains cannot be accidentally mixed. For branded schemas, the default constructor accepts an unbranded input and returns a branded output.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.String.pipe(Schema.brand<"a">())

// make(input: string, options?: Schema.MakeOptions): string & Brand<"a">
schema.make
```

However, when a branded schema is part of a composite (such as a struct), you must pass a branded value.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String.pipe(Schema.brand<"a">()),
  b: Schema.Number
})

/*
make(input: {
    readonly a: string & Brand<"a">;
    readonly b: number;
}, options?: Schema.MakeOptions): {
    readonly a: string & Brand<"a">;
    readonly b: number;
}
*/
schema.make
```

## Refined Constructors

For refined schemas, the constructor accepts the unrefined type and returns the refined one.

```ts
import { Option, Schema } from "effect/unstable/schema"

const schema = Schema.Option(Schema.String).pipe(Schema.refine(Option.isSome))

// make(input: Option.Option<string>, options?: Schema.MakeOptions): Option.Some<string>
schema.make
```

## Default Values in Constructors

You can define a default value for a field using `Schema.withConstructorDefault`.

**Example** (Providing a default number)

```ts
import { Option, Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.Number.pipe(Schema.withConstructorDefault(() => Option.some(-1)))
})

console.log(schema.make({ a: 5 }))
// { a: 5 }

console.log(schema.make({}))
// { a: -1 }
```

The function passed to `withConstructorDefault` will be executed each time a default value is needed.

**Example** (Re-executing the default function)

```ts
import { Option, Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.Date.pipe(Schema.withConstructorDefault(() => Option.some(new Date())))
})

console.log(schema.make({}))
// { a: 2025-05-19T16:46:10.912Z }

console.log(schema.make({}))
// { a: 2025-05-19T16:46:10.913Z }
```

### Nested Constructor Default Values

Default values can be nested inside composed schemas. In this case, inner defaults are resolved first.

```ts
import { Option, Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.Struct({
    b: Schema.Number.pipe(Schema.withConstructorDefault(() => Option.some(-1)))
  }).pipe(Schema.withConstructorDefault(() => Option.some({})))
})

console.log(schema.make({}))
// { a: { b: -1 } }
console.log(schema.make({ a: {} }))
// { a: { b: -1 } }
```

## Effectful Defaults

Default values can also come from an `Effect` — for example, reading from a configuration service or performing an asynchronous operation.

**Example** (Using an effect to provide a default)

```ts
import { Effect, Option, Schema, SchemaParser } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.Number.pipe(
    Schema.withConstructorDefault(() =>
      Effect.gen(function*() {
        yield* Effect.sleep(100)
        return Option.some(-1)
      })
    )
  )
})

SchemaParser.makeEffect(schema)({}).pipe(Effect.runPromise).then(console.log)
// { a: -1 }
```

## See Also

- [schema-validation.md](schema-validation.md) - Filter and refinement functions
- [schema-classes.md](schema-classes.md) - Class-based constructors with make
