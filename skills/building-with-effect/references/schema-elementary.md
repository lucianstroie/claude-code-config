---
name: schema-elementary
description: Built-in schemas for primitives, literals, strings, numbers, dates, and template literals. Use when defining basic data types with Effect Schema.
---

# Elementary Schemas

Schema provides built-in schemas for all common TypeScript types. These schemas represent a single value — like a string or a number — and they are the building blocks you combine into more complex shapes.

## Table of Contents

- [Primitives](#primitives)
- [Literals](#literals)
- [Strings](#strings)
- [String formats](#string-formats)
- [Numbers](#numbers)
- [Integers](#integers)
- [BigInts](#bigints)
- [Dates](#dates)
- [Template literals](#template-literals)

## Primitives

Use these schemas when a value should be exactly one of the basic JavaScript types.

```ts
import { Schema } from "effect/unstable/schema"

// primitive types
Schema.String
Schema.Number
Schema.BigInt
Schema.Boolean
Schema.Symbol
Schema.Undefined
Schema.Null
```

Sometimes you receive data that is not the right type yet — for example, a number that should become a string. You can build a schema that converts (coerces) values to the target type during decoding:

```ts
import { Getter, Parser, Schema } from "effect/unstable/schema"

//      ┌─── Codec<string, unknown>
//      ▼
const schema = Schema.Unknown.pipe(
  Schema.decodeTo(Schema.String, {
    decode: Getter.String(),
    encode: Getter.passthrough()
  })
)

const parser = Parser.decodeUnknownSync(schema)

console.log(parser("tuna")) // => "tuna"
console.log(parser(42)) // => "42"
console.log(parser(true)) // => "true"
console.log(parser(null)) // => "null"
```

## Literals

A literal schema matches one exact value. Use it when a field must be a specific string, number, or other constant.

```ts
import { Schema } from "effect/unstable/schema"

const tuna = Schema.Literal("tuna")
const twelve = Schema.Literal(12)
const twobig = Schema.Literal(2n)
const tru = Schema.Literal(true)
```

Symbol literals:

```ts
import { Schema } from "effect/unstable/schema"

const terrific = Schema.UniqueSymbol(Symbol("terrific"))
```

`null`, `undefined`, and `void`:

```ts
import { Schema } from "effect/unstable/schema"

Schema.Null
Schema.Undefined
Schema.Void
```

To allow multiple literal values:

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Literals(["red", "green", "blue"])
```

To extract the set of allowed values from a literal schema:

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Literals(["red", "green", "blue"])

// readonly ["red", "green", "blue"]
schema.literals

// readonly [Schema.Literal<"red">, Schema.Literal<"green">, Schema.Literal<"blue">]
schema.members
```

## Strings

You can add validation rules to a string schema. Each rule is applied with `.check(...)` and returns a new schema that enforces that constraint.

```ts
import { Schema } from "effect/unstable/schema"

Schema.String.check(Schema.isMaxLength(5))
Schema.String.check(Schema.isMinLength(5))
Schema.String.check(Schema.isLengthBetween(5, 5))
Schema.String.check(Schema.isPattern(/^[a-z]+$/))
Schema.String.check(Schema.isStartsWith("aaa"))
Schema.String.check(Schema.isEndsWith("zzz"))
Schema.String.check(Schema.isIncludes("---"))
Schema.String.check(Schema.isUppercased())
Schema.String.check(Schema.isLowercased())
```

To perform some simple string transforms:

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

Schema.String.decode(SchemaTransformation.trim())
Schema.String.decode(SchemaTransformation.toLowerCase())
Schema.String.decode(SchemaTransformation.toUpperCase())
```

## String formats

Schema includes built-in checks for common string formats.

```ts
import { Schema } from "effect/unstable/schema"

Schema.String.check(Schema.isUUID())
Schema.String.check(Schema.isBase64())
Schema.String.check(Schema.isBase64Url())
```

## Numbers

```ts
import { Schema } from "effect/unstable/schema"

Schema.Number // all numbers
Schema.Finite // finite numbers (i.e. not +/-Infinity or NaN)
```

You can add validation rules to a number schema. Each rule constrains the allowed range or value.

```ts
import { Schema } from "effect/unstable/schema"

Schema.Number.check(Schema.isBetween({ minimum: 5, maximum: 10 }))
Schema.Number.check(Schema.isGreaterThan(5))
Schema.Number.check(Schema.isGreaterThanOrEqualTo(5))
Schema.Number.check(Schema.isLessThan(5))
Schema.Number.check(Schema.isLessThanOrEqualTo(5))
Schema.Number.check(Schema.isMultipleOf(5))
```

## Integers

To require that a number has no decimal part, use `isInt()`. For 32-bit integers specifically, use `isInt32()`.

```ts
import { Schema } from "effect/unstable/schema"

Schema.Number.check(Schema.isInt())
Schema.Number.check(Schema.isInt32())
```

## BigInts

Schema does not ship pre-built BigInt validation factories (unlike numbers). Instead, you create your own using helper functions and a BigInt-compatible ordering. The example below shows how.

```ts
import { BigInt, Order, Schema } from "effect/unstable/schema"

const options = { order: Order.BigInt }

const isBetween = Schema.makeIsBetween(options)
const isGreaterThan = Schema.makeIsGreaterThan(options)
const isGreaterThanOrEqualTo = Schema.makeIsGreaterThanOrEqualTo(options)
const isLessThan = Schema.makeIsLessThan(options)
const isLessThanOrEqualTo = Schema.makeIsLessThanOrEqualTo(options)
const isMultipleOf = Schema.makeIsMultipleOf({
  remainder: BigInt.remainder,
  zero: 0n
})

const isPositive = isGreaterThan(0n)
const isNonNegative = isGreaterThanOrEqualTo(0n)
const isNegative = isLessThan(0n)
const isNonPositive = isLessThanOrEqualTo(0n)

Schema.BigInt.check(isBetween({ minimum: 5n, maximum: 10n }))
Schema.BigInt.check(isGreaterThan(5n))
Schema.BigInt.check(isGreaterThanOrEqualTo(5n))
Schema.BigInt.check(isLessThan(5n))
Schema.BigInt.check(isLessThanOrEqualTo(5n))
Schema.BigInt.check(isMultipleOf(5n))
Schema.BigInt.check(isPositive)
Schema.BigInt.check(isNonNegative)
Schema.BigInt.check(isNegative)
Schema.BigInt.check(isNonPositive)
```

## Dates

The `Schema.Date` schema matches `Date` objects. You can combine it with a string encoding to decode date strings into `Date` instances.

```ts
import { Schema, SchemaGetter } from "effect/unstable/schema"

Schema.Date

const DateFromString = Schema.Date.pipe(
  Schema.encodeTo(Schema.String, {
    decode: SchemaGetter.Date(),
    encode: SchemaGetter.String()
  })
)
```

## Template literals

You can use `Schema.TemplateLiteral` to define structured string patterns made of multiple parts. Each part can be a literal or a schema, and **additional constraints** (such as `isMinLength` or `isMaxLength`) can be applied to individual parts.

**Example** (Constraining parts of an email-like string)

```ts
import { Schema } from "effect/unstable/schema"

// Construct a template literal schema for values like `${string}@${string}`
// Apply constraints to both sides of the "@" symbol
const email = Schema.TemplateLiteral([
  // Left part: must be a non-empty string
  Schema.String.check(Schema.isMinLength(1)),

  // Separator
  "@",

  // Right part: must be a string with a maximum length of 64
  Schema.String.check(Schema.isMaxLength(64))
])

// The inferred type is `${string}@${string}`
export type Type = typeof email.Type

console.log(String(Schema.decodeUnknownExit(email)("a@b.com")))
/*
Success("a@b.com")
*/

console.log(String(Schema.decodeUnknownExit(email)("@b.com")))
/*
Failure(Cause([Fail(SchemaError(Expected a value with a length of at least 1, got ""
  at [0]))]))
*/
```

### Template literal parser

If you want to extract the parts of a string that match a template, you can use `Schema.TemplateLiteralParser`. This allows you to parse the input into its individual components rather than treat it as a single string.

**Example** (Parsing a template literal into components)

```ts
import { Schema } from "effect/unstable/schema"

const email = Schema.TemplateLiteralParser([
  Schema.String.check(Schema.isMinLength(1)),
  "@",
  Schema.String.check(Schema.isMaxLength(64))
])

// The inferred type is `readonly [string, "@", string]`
export type Type = typeof email.Type

console.log(String(Schema.decodeUnknownExit(email)("a@b.com")))
/*
Success(["a","@","b.com"])
*/
```

## See Also

- [schema-composite.md](schema-composite.md) - Structs, Tuples, Arrays, Records, Unions
- [schema-validation.md](schema-validation.md) - Adding runtime checks with filters
