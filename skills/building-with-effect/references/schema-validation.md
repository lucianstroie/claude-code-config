---
name: schema-validation
description: Add runtime validation with filters, refinements, and branding. Use when constraining values at runtime with Effect Schema.
---

# Validation

After defining a schema's shape, you can add validation rules called _filters_. Filters check runtime values against constraints like minimum length, numeric range, or custom predicates.

## Table of Contents

- [Filters](#filters)
- [Preserving Schema Type After Filtering](#preserving-schema-type-after-filtering)
- [Filters as First-Class](#filters-as-first-class)
- [Multiple Issues Reporting](#multiple-issues-reporting)
- [Aborting Validation](#aborting-validation)
- [Filter Groups](#filter-groups)
- [Refinements](#refinements)
- [Branding](#branding)
- [Structural Filters](#structural-filters)
- [Effectful Filters](#effectful-filters)
- [Filter Factories](#filter-factories)

## Filters

Define custom filters with `Schema.makeFilter`.

**Example** (Custom filter that checks minimum length)

```ts
import { Schema } from "effect/unstable/schema"

// Filter: the string must have at least 3 characters
const schema = Schema.String.check(Schema.makeFilter((s) => s.length >= 3))

console.log(String(Schema.decodeUnknownExit(schema)("")))
// Failure(Cause([Fail(SchemaError: Expected <filter>, got "")]))
```

You can attach annotations and provide a custom error message when defining a filter.

**Example** (Filter with annotations and a custom message)

```ts
import { Schema } from "effect/unstable/schema"

// Filter with a title, description, and custom error message
const schema = Schema.String.check(
  Schema.makeFilter((s) => s.length >= 3 || `length must be >= 3, got ${s.length}`, {
    title: "length >= 3",
    description: "a string with at least 3 characters"
  })
)

console.log(String(Schema.decodeUnknownExit(schema)("")))
// Failure(Cause([Fail(SchemaError: length must be >= 3, got 0)]))
```

## Preserving Schema Type After Filtering

Adding a filter does not change the schema's type. You can still use all schema-specific methods (like `.fields` on a struct or `.make`) after calling `.check(...)`.

**Example** (Chaining filters and annotations without losing type information)

```ts
import { Schema } from "effect/unstable/schema"

//      ┌─── Schema.String
//      ▼
Schema.String

//      ┌─── Schema.String
//      ▼
const NonEmptyString = Schema.String.check(Schema.isNonEmpty())

//      ┌─── Schema.String
//      ▼
const schema = NonEmptyString.annotate({})
```

## Filters as First-Class

Filters are standalone values that you can define once and reuse across different schemas.

You can pass multiple filters to a single `.check(...)` call.

**Example** (Combining filters on a string)

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.String.check(
  Schema.isMinLength(3), // value must be at least 3 chars long
  Schema.isTrimmed() // no leading/trailing whitespace
)

console.log(String(Schema.decodeUnknownExit(schema)(" a")))
// Failure(Cause([Fail(SchemaError: Expected a value with a length of at least 3, got " a")]))
```

**Example** (Validating array length)

```ts
import { Schema } from "effect/unstable/schema"

// Array must contain at least 3 strings
const schema = Schema.Array(Schema.String).check(Schema.isMinLength(3))

console.log(String(Schema.decodeUnknownExit(schema)(["a", "b"])))
// Failure(Cause([Fail(SchemaError: Expected a value with a length of at least 3, got ["a","b"]]))
```

## Multiple Issues Reporting

By default, when `{ errors: "all" }` is passed, all filters are evaluated, even if one fails. This allows multiple issues to be reported at once.

**Example** (Collecting multiple validation issues)

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.String.check(Schema.isMinLength(3), Schema.isTrimmed())

console.log(
  String(
    Schema.decodeUnknownExit(schema)(" a", {
      errors: "all"
    })
  )
)
/*
Failure(Cause([Fail(SchemaError: Expected a value with a length of at least 3, got " a"
Expected a string with no leading or trailing whitespace, got " a")]))
*/
```

## Aborting Validation

If you want to stop validation as soon as a filter fails, you can call the `abort` method on the filter.

**Example** (Short-circuit on first failure)

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.String.check(
  Schema.isMinLength(3).abort(), // Stop on failure here
  Schema.isTrimmed() // This will not run if minLength fails
)
```

## Filter Groups

Group filters into a reusable unit with `Schema.makeFilterGroup`.

**Example** (Reusable group for 32-bit integers)

```ts
import { Schema } from "effect/unstable/schema"

//      ┌─── FilterGroup<number>
//      ▼
const isInt32 = Schema.makeFilterGroup(
  [Schema.isInt(), Schema.isBetween({ minimum: -2147483648, maximum: 2147483647 })],
  {
    title: "isInt32",
    description: "a 32-bit integer"
  }
)
```

## Refinements

Use `Schema.refine` to refine a schema to a more specific type.

**Example** (Require at least two items in a string array)

```ts
import { Schema } from "effect/unstable/schema"

const refined = Schema.Array(Schema.String).pipe(
  Schema.refine((arr): arr is readonly [string, string, ...Array<string>] => arr.length >= 2)
)
```

## Branding

Use `Schema.brand` to add a brand to a schema.

**Example** (Brand a string as a UserId)

```ts
import { Schema } from "effect/unstable/schema"

//      ┌─── Schema.brand<Schema.String, "UserId">
//      ▼
const branded = Schema.String.pipe(Schema.brand("UserId"))
```

## Structural Filters

Some filters check the structure of a value rather than its contents — for example, the number of items in an array or the number of keys in an object. These are called **structural filters**.

**Example** (Validating an array with item and structural constraints)

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  tags: Schema.Array(Schema.String.check(Schema.isNonEmpty())).check(
    Schema.isMinLength(3) // structural filter
  )
})

console.log(String(Schema.decodeUnknownExit(schema)({ tags: ["a", ""] }, { errors: "all" })))
/*
Failure(Cause([Fail(SchemaError: Expected a value with a length of at least 1, got ""
  at ["tags"][1]
Expected a value with a length of at least 3, got ["a",""]
  at ["tags"])]))
*/
```

## Effectful Filters

Filters passed to `.check(...)` must be synchronous. When you need to call an API or use a service during validation, use an effectful filter instead.

Define an effectful filter with `Getter.checkEffect` as part of a transformation.

**Example** (Asynchronous validation of a numeric value)

```ts
import { Effect, Option, Result, Schema, SchemaGetter, SchemaIssue } from "effect/unstable/schema"

// Simulated API call that fails when userId is 0
const myapi = (userId: number) =>
  Effect.gen(function*() {
    if (userId === 0) {
      return new Error("not found")
    }
    return { userId }
  }).pipe(Effect.delay(100))

const schema = Schema.Finite.pipe(
  Schema.decode({
    decode: SchemaGetter.checkEffect((n) =>
      Effect.gen(function*() {
        const user = yield* Effect.result(myapi(n))
        return Result.isFailure(user) ? new SchemaIssue.InvalidValue(Option.some(n), { title: "not found" }) : undefined
      })
    ),
    encode: SchemaGetter.passthrough()
  })
)
```

## Filter Factories

A filter factory is a function that returns a new filter each time you call it, letting you parameterize the constraint.

**Example** (Factory for a `isGreaterThan` filter on ordered values)

```ts
import { Order, Schema } from "effect/unstable/schema"

export const makeGreaterThan = <T>(options: {
  readonly order: Order.Order<T>
  readonly annotate?: ((exclusiveMinimum: T) => Schema.Annotations.Filter) | undefined
  readonly format?: (value: T) => string | undefined
}) => {
  const greaterThan = Order.isGreaterThan(options.order)
  const format = options.format ?? globalThis.String
  return (exclusiveMinimum: T, annotations?: Schema.Annotations.Filter) => {
    return Schema.makeFilter<T>((input) => greaterThan(input, exclusiveMinimum), {
      title: `greaterThan(${format(exclusiveMinimum)})`,
      description: `a value greater than ${format(exclusiveMinimum)}`,
      ...options.annotate?.(exclusiveMinimum),
      ...annotations
    })
  }
}
```

## See Also

- [schema-elementary.md](schema-elementary.md) - Built-in filter functions like isMinLength, isMaxLength
- [schema-constructors.md](schema-constructors.md) - Constructor behavior with branded/refined schemas
