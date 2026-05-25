---
name: schema-recursive
description: Define self-referential schemas with Schema.suspend. Use when defining recursive types like trees or linked lists.
---

# Recursive Schemas

Use `Schema.suspend` when a schema needs to refer to itself (or to another schema that eventually refers back). `suspend` wraps a thunk, so the recursive reference is resolved lazily during decode / encode instead of eagerly during declaration.

## Table of Contents

- [Recursive Struct with Same Encoded and Type](#recursive-struct-with-same-encoded-and-type)
- [Recursive Struct with Different Encoded and Type](#recursive-struct-with-different-encoded-and-type)
- [Recursive Union](#recursive-union)

## Recursive Struct with Same Encoded and Type

**Example** (Recursive Struct with Same Encoded and Type)

```ts
import { Schema } from "effect/unstable/schema"

interface Category {
  readonly name: string
  readonly children: ReadonlyArray<Category>
}

const Category: Schema.Codec<Category> = Schema.Struct({
  name: Schema.String,
  children: Schema.Array(Schema.suspend((): Schema.Codec<Category> => Category))
})
```

The explicit `Schema.Codec<Category>` annotation is important in recursive declarations because `Category` is referenced inside its own initializer. Without the annotation, TypeScript often cannot stabilize the self-referential type and falls back to an implicit `any` style error.

## Recursive Struct with Different Encoded and Type

**Example** (Recursive Struct with Different Encoded and Type)

```ts
import { Schema } from "effect/unstable/schema"

interface Category {
  readonly name: number
  readonly children: ReadonlyArray<Category>
}

interface CategoryEncoded {
  readonly name: string
  readonly children: ReadonlyArray<CategoryEncoded>
}

const Category: Schema.Codec<Category, CategoryEncoded> = Schema.Struct({
  name: Schema.FiniteFromString,
  children: Schema.Array(Schema.suspend((): Schema.Codec<Category, CategoryEncoded> => Category))
})
```

Here the encoded shape differs from the runtime shape (`name` is `string` when encoded, `number` after decoding), so both type parameters must be explicit: `Schema.Codec<Category, CategoryEncoded>`.

Using only `Schema.Codec<Category>` would force encoded and decoded types to be the same, which does not describe this schema.

## Recursive Union

**Example** (Recursive Union)

```ts
import { Schema } from "effect/unstable/schema"

type U = A | B

interface A {
  readonly a: string
  readonly next: U
}
interface B {
  readonly b: number
  readonly next: U
}

const URef = Schema.suspend((): Schema.Codec<U> => U)

const A: Schema.Codec<A> = Schema.Struct({
  a: Schema.String,
  next: URef
})

const B: Schema.Codec<B> = Schema.Struct({
  b: Schema.Number,
  next: URef
})

const U: Schema.Codec<U> = Schema.Union([A, B])
```

`URef` factors the recursive edge (`U -> U`) into one shared `Schema.suspend` value. Reusing it across members avoids duplicating the lazy reference and makes the intent clear: every variant points back to the same union schema.

## See Also

- [schema-composite.md](schema-composite.md) - Structs, Tuples, Arrays, Records, Unions
- [schema-classes.md](schema-classes.md) - Recursive Opaque Structs
