---
name: schema-flipping
description: Swap decode/encode directions with Schema.flip. Use when you need to invert a schema's transformation direction.
---

# Flipping Schemas

Flipping a schema swaps its decoding and encoding directions. If a schema decodes a `string` into a `number`, the flipped version decodes a `number` into a `string`.

## Table of Contents

- [Flipping a Schema](#flipping-a-schema)
- [Accessing the Original Schema](#accessing-the-original-schema)
- [Double Flipping](#double-flipping)
- [How it Works](#how-it-works)
- [Flipped Constructors](#flipped-constructors)

## Flipping a Schema

**Example** (Flipping a schema that parses a string into a number)

```ts
import { Schema } from "effect/unstable/schema"

// Flips a schema that decodes a string into a number,
// turning it into one that decodes a number into a string
//
//      ┌─── flip<FiniteFromString>
//      ▼
const StringFromFinite = Schema.flip(Schema.FiniteFromString)
```

## Accessing the Original Schema

You can access the original schema using the `.schema` property:

```ts
import { Schema } from "effect/unstable/schema"

const StringFromFinite = Schema.flip(Schema.FiniteFromString)

//                 ┌─── FiniteFromString
//                 ▼
StringFromFinite.schema
```

## Double Flipping

Flipping a schema twice returns a schema with the same structure and behavior as the original:

```ts
import { Schema } from "effect/unstable/schema"

//      ┌─── FiniteFromString
//      ▼
const schema = Schema.flip(Schema.flip(Schema.FiniteFromString))
```

## How it Works

All internal operations in the Schema AST are symmetrical. Encoding with a schema is equivalent to decoding with its flipped version:

```ts
// Encoding with a schema is the same as decoding with its flipped version
encode(schema) = decode(flip(schema))
```

This symmetry ensures that flipping works consistently across all schema types.

## Flipped Constructors

A flipped schema also includes a constructor. It builds values of the **encoded** type from the original schema.

**Example** (Using a flipped schema to construct an encoded value)

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.FiniteFromString
})

/*
type Encoded = {
    readonly a: string;
}
*/
type Encoded = (typeof schema)["Encoded"]

// make: { readonly a: string }  ──▶  { readonly a: string }
Schema.flip(schema).make
```

## See Also

- [schema-transformations.md](schema-transformations.md) - Transformations between schemas
- [schema-constructors.md](schema-constructors.md) - Constructor behavior
