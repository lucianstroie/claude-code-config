---
name: schema-transformations
description: Transform values during decoding and encoding with decodeTo, encodeTo, and SchemaTransformation. Use when converting between types with Effect Schema.
---

# Transformations

Transformations convert values from one type to another during decoding or encoding.

## Table of Contents

- [Transformations as First-Class](#transformations-as-first-class)
- [The Transformation Type](#the-transformation-type)
- [Composing Transformations](#composing-transformations)
- [Transforming One Schema into Another](#transforming-one-schema-into-another)
  - [decodeTo](#decodeto)
  - [decode](#decode)
  - [Defining an Inline Transformation](#defining-an-inline-transformation)
- [Schema composition](#schema-composition)
- [Passthrough Helpers](#passthrough-helpers)
- [Managing Optional Keys](#managing-optional-keys)
- [Omitting a Key During Encoding](#omitting-a-key-during-encoding)

## Transformations as First-Class

In previous versions, transformations were directly embedded in schemas. In the current version, they are defined as independent values that can be reused across schemas.

**Example** (The `trim` built-in transformation)

```ts
import { SchemaTransformation } from "effect/unstable/schema"

// const t: Transformation<string, string, never, never>
const t = SchemaTransformation.trim()
```

You can apply a transformation to any compatible schema using `Schema.decode`.

**Example** (Applying `trim` to a string schema)

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

const schema = Schema.String.pipe(Schema.decode(SchemaTransformation.trim()))

console.log(Schema.decodeUnknownSync(schema)("  123"))
// 123
```

## The Transformation Type

A `Transformation` carries four type parameters:

```ts
Transformation<T, E, RD, RE>
```

- `T`: the decoded (output) type
- `E`: the encoded (input) type
- `RD`: the context used while decoding
- `RE`: the context used while encoding

A `Transformation` consists of two `Getter` functions:

- `decode: Getter<T, E, RD>` — transforms a value during decoding
- `encode: Getter<E, T, RE>` — transforms a value during encoding

**Example** (Implementation of `Transformation.trim`)

```ts
export function trim(): Transformation<string, string> {
  return new Transformation(Getter.trim(), Getter.passthrough())
}
```

## Composing Transformations

You can combine transformations using the `.compose` method.

**Example** (Trim and lowercase a string)

```ts
import { Option, SchemaTransformation } from "effect/unstable/schema"

const trimToLowerCase = SchemaTransformation.trim().compose(SchemaTransformation.toLowerCase())

console.log(trimToLowerCase.decode.run(Option.some("  Abc"), {}))
/*
{
  _id: 'Exit',
  _tag: 'Success',
  value: { _id: 'Option', _tag: 'Some', value: 'abc' }
}
*/
```

## Transforming One Schema into Another

To define how one schema transforms into another, you can use:

- `Schema.decodeTo` (and its inverse `Schema.encodeTo`)
- `Schema.decode` (and its inverse `Schema.encode`)

### decodeTo

Use `Schema.decodeTo` when you want to transform a source schema into a different target schema.

**Example** (Parsing a number from a string)

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

const NumberFromString =
  Schema.String.pipe(
    Schema.decodeTo(
      Schema.Number,
      SchemaTransformation.numberFromString
    )
  )

console.log(Schema.decodeUnknownSync(NumberFromString)("123"))
// 123
console.log(Schema.decodeUnknownSync(NumberFromString)("a"))
// NaN
```

### decode

Use `Schema.decode` when the source and target schemas are the same and you only want to apply a transformation.

**Example** (Trimming whitespace from a string)

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

const TrimmedString = Schema.String.pipe(Schema.decode(SchemaTransformation.trim()))
```

### Defining an Inline Transformation

You can create a transformation directly using helpers from the `SchemaTransformation` module.

**Example** (Converting meters to kilometers and back)

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

const Kilometers = Schema.Finite.pipe(
  Schema.decode(
    SchemaTransformation.transform({
      decode: (meters) => meters / 1000,
      encode: (kilometers) => kilometers * 1000
    })
  )
)
```

You can define transformations that may fail during decoding or encoding using `SchemaTransformation.transformOrFail`.

**Example** (Converting a string URL into a `URL` object)

```ts
import { Effect, Option, Schema, SchemaIssue, SchemaTransformation } from "effect/unstable/schema"

const URLFromString = Schema.String.pipe(
  Schema.decodeTo(
    Schema.instanceOf(URL),
    SchemaTransformation.transformOrFail({
      decode: (s) =>
        Effect.try({
          try: () => new URL(s),
          catch: (error) => new SchemaIssue.InvalidValue(Option.some(s), { cause: error })
        }),
      encode: (url) => Effect.succeed(url.toString())
    })
  )
)
```

## Schema composition

You can compose transformations, but you can also compose schemas with `Schema.decodeTo`.

**Example** (Converting meters to miles via kilometers)

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

const KilometersFromMeters = Schema.Finite.pipe(
  Schema.decode(
    SchemaTransformation.transform({
      decode: (meters) => meters / 1000,
      encode: (kilometers) => kilometers * 1000
    })
  )
)

const MilesFromKilometers = Schema.Finite.pipe(
  Schema.decode(
    SchemaTransformation.transform({
      decode: (kilometers) => kilometers * 0.621371,
      encode: (miles) => miles / 0.621371
    })
  )
)

const MilesFromMeters = KilometersFromMeters.pipe(Schema.decodeTo(MilesFromKilometers))
```

## Passthrough Helpers

The `passthrough`, `passthroughSubtype`, and `passthroughSupertype` helpers let you compose schemas by describing how their types relate.

### passthrough

Use `passthrough` when the encoded output of the target schema matches the type of the source schema.

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

const From = Schema.Struct({ a: Schema.String })
const To = Schema.Struct({ a: Schema.FiniteFromString })

// To.Encoded (string) = From.Type (string)
const schema = From.pipe(Schema.decodeTo(To, SchemaTransformation.passthrough()))
```

## Managing Optional Keys

You can control how optional values are handled during transformations using `SchemaTransformation.transformOptional`.

**Example** (Optional string key transformed to `Option<NonEmptyString>`)

```ts
import { Option, Schema, SchemaTransformation } from "effect/unstable/schema"

const OptionFromNonEmptyString = Schema.optionalKey(Schema.String).pipe(
  Schema.decodeTo(
    Schema.Option(Schema.NonEmptyString),
    SchemaTransformation.transformOptional({
      decode: (oe) =>
        Option.isSome(oe) && oe.value !== "" ? Option.some(Option.some(oe.value)) : Option.some(Option.none()),
      encode: (ot) => Option.flatten(ot)
    })
  )
)
```

## Omitting a Key During Encoding

Use `SchemaGetter.omit()` to exclude a field from the encoded output.

**Example** (Field present when decoded, omitted when encoded)

```ts
import { Schema, SchemaGetter } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.FiniteFromString,
  b: Schema.String.pipe(
    Schema.encodeTo(Schema.optionalKey(Schema.String), {
      decode: SchemaGetter.withDefault(() => "default_value"),
      encode: SchemaGetter.omit()
    })
  )
})

console.log(Schema.decodeUnknownSync(schema)({ a: "1", b: "value" }))
// Output: { a: 1, b: "value" }

console.log(Schema.decodeUnknownSync(schema)({ a: "1" }))
// Output: { a: 1, b: "default_value" }

console.log(Schema.encodeSync(schema)({ a: 1, b: "default_value" }))
// Output: { a: "1" }
```

## See Also

- [schema-elementary.md](schema-elementary.md) - String transformations (trim, toLowerCase, etc.)
- [schema-composite.md](schema-composite.md) - Struct transformations
