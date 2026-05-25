---
name: schema-composite
description: Combine elementary schemas into structs, tuples, arrays, records, and unions. Use when defining complex data shapes with Effect Schema.
---

# Composite Schemas

Once you have elementary schemas, you can combine them into composite schemas that describe objects, arrays, tuples, key-value maps, and unions.

## Table of Contents

- [Structs](#structs)
  - [Optional and Mutable Keys](#optional-and-mutable-keys)
  - [Optional Fields](#optional-fields)
  - [Key Annotations](#key-annotations)
  - [Index Signatures](#index-signatures)
  - [Reusing Fields](#reusing-fields)
  - [Deriving Structs](#deriving-structs)
  - [Tagged Structs](#tagged-structs)
- [Tuples](#tuples)
  - [Rest Elements](#rest-elements)
  - [Element Annotations](#element-annotations)
  - [Deriving Tuples](#deriving-tuples)
- [Arrays](#arrays)
  - [Unique Arrays](#unique-arrays)
- [Records](#records)
  - [Key Transformations](#key-transformations)
  - [Number Keys](#number-keys)
  - [Mutability](#mutability)
  - [Literal Structs](#literal-structs)
- [Unions](#unions)
  - [Excluding Incompatible Members](#excluding-incompatible-members)
  - [Exclusive Unions](#exclusive-unions)
  - [Deriving Unions](#deriving-unions)
  - [Union of Literals](#union-of-literals)
  - [Tagged Unions](#tagged-unions)

## Structs

A struct schema describes a JavaScript object with a known set of keys. Each key maps to a schema that validates and types its value.

### Optional and Mutable Keys

By default, every key in a struct is required and readonly. Use `Schema.optionalKey` to make a key optional (the key can be absent from the object), and `Schema.mutableKey` to make it writable.

You can mark struct properties as optional or mutable using `Schema.optionalKey` and `Schema.mutableKey`.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String,
  b: Schema.optionalKey(Schema.String),
  c: Schema.mutableKey(Schema.String),
  d: Schema.optionalKey(Schema.mutableKey(Schema.String))
})

/*
with "exactOptionalPropertyTypes": true

type Type = {
    readonly a: string;
    readonly b?: string;
    c: string;
    d?: string;
}
*/
type Type = (typeof schema)["Type"]
```

### Optional Fields

There are several ways to represent optional properties, depending on whether you want `undefined` in the type, `null` in the type, or just a missing key. By combining `Schema.optionalKey`, `Schema.optional`, and `Schema.NullOr`, you can represent any variant.

```ts
import { Schema } from "effect/unstable/schema"

export const schema = Schema.Struct({
  // Exact Optional Property
  a: Schema.optionalKey(Schema.FiniteFromString),
  // Optional Property
  b: Schema.optional(Schema.FiniteFromString),
  // Exact Optional Property with Nullability
  c: Schema.optionalKey(Schema.NullOr(Schema.FiniteFromString)),
  // Optional Property with Nullability
  d: Schema.optional(Schema.NullOr(Schema.FiniteFromString))
})

/*
type Encoded = {
    readonly a?: string;
    readonly b?: string | undefined;
    readonly c?: string | null;
    readonly d?: string | null | undefined;
}
*/
type Encoded = typeof schema.Encoded

/*
type Type = {
    readonly a?: number;
    readonly b?: number | undefined;
    readonly c?: number | null;
    readonly d?: number | null | undefined;
}
*/
type Type = typeof schema.Type
```

#### Omitting Values When Transforming Optional Fields

If an optional field arrives as `undefined`, you may want to omit it from the output entirely rather than keeping it.

```ts
import { Option, Predicate, Schema, SchemaGetter } from "effect/unstable/schema"

export const schema = Schema.Struct({
  a: Schema.optional(Schema.FiniteFromString).pipe(
    Schema.decodeTo(Schema.optionalKey(Schema.Number), {
      decode: SchemaGetter.transformOptional(
        Option.filter(Predicate.isNotUndefined) // omit undefined
      ),
      encode: SchemaGetter.passthrough()
    })
  )
})
```

#### Decoding Defaults

You can assign default values to fields during decoding using:

- `Schema.withDecodingDefaultKey`: for optional fields
- `Schema.withDecodingDefault`: for optional or undefined fields

**Example** (Providing a default for a missing or undefined value)

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.FiniteFromString.pipe(Schema.withDecodingDefault(() => "1"))
})

//     ┌─── { readonly a?: string | undefined; }
//     ▼
type Encoded = typeof schema.Encoded

//     ┌─── { readonly a: number; }
//     ▼
type Type = typeof schema.Type

console.log(Schema.decodeUnknownSync(schema)({}))
// Output: { a: 1 }

console.log(Schema.decodeUnknownSync(schema)({ a: undefined }))
// Output: { a: 1 }

console.log(Schema.decodeUnknownSync(schema)({ a: "2" }))
// Output: { a: 2 }
```

### Key Annotations

You can annotate individual keys using the `annotateKey` method.

**Example** (Annotating a required `username` field)

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  username: Schema.String.annotateKey({
    description: "The username used to log in",
    // Custom message shown if the key is missing
    messageMissingKey: "Username is required"
  })
})
```

### Unexpected Key Message

You can annotate a struct with a custom message to use when a key is unexpected.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String
}).annotate({ messageUnexpectedKey: "Custom message" })
```

### Preserve unexpected keys

You can preserve unexpected keys by setting `onExcessProperty` to `preserve`.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String
})

console.log(String(Schema.decodeUnknownExit(schema)({ a: "a", b: "b" }, { onExcessProperty: "preserve" })))
/*
Success({"b":"b","a":"a"})
*/
```

### Index Signatures

An index signature lets a struct accept any string key in addition to its fixed keys. Use `Schema.StructWithRest` to combine a struct with one or more record schemas.

**Example** (Combining fixed properties with an index signature)

```ts
import { Schema } from "effect/unstable/schema"

// Define a schema with one fixed key "a" and any number of string keys mapping to numbers
export const schema = Schema.StructWithRest(Schema.Struct({ a: Schema.Number }), [
  Schema.Record(Schema.String, Schema.Number)
])

/*
type Type = {
    readonly [x: string]: number;
    readonly a: number;
}
*/
type Type = typeof schema.Type
```

### Reusing Fields

Every `Schema.Struct` exposes a `.fields` property containing its field definitions. You can spread these fields into a new struct to reuse them.

**Example** (Single inheritance)

```ts
import { Schema } from "effect/unstable/schema"

const Timestamped = Schema.Struct({
  createdAt: Schema.Date,
  updatedAt: Schema.Date
})

const User = Schema.Struct({
  ...Timestamped.fields,
  name: Schema.String,
  email: Schema.String
})
```

### Deriving Structs

You can derive new struct schemas from existing ones — picking, omitting, renaming, or transforming individual fields — without rewriting the schema from scratch.

#### Pick

Use `Struct.pick` to keep only a selected set of fields.

```ts
import { Schema, Struct } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String,
  b: Schema.Number
}).mapFields(Struct.pick(["a"]))
```

#### Omit

Use `Struct.omit` to remove specified fields from a struct.

```ts
import { Schema, Struct } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String,
  b: Schema.Number
}).mapFields(Struct.omit(["b"]))
```

#### Merge

Use `Struct.assign` to add new fields to an existing struct.

```ts
import { Schema, Struct } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String,
  b: Schema.Number
}).mapFields(
  Struct.assign({
    c: Schema.Boolean
  })
)
```

#### Mapping individual fields

Use `Struct.evolve` to transform the value schema of individual fields.

```ts
import { Schema, Struct } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String,
  b: Schema.Number
}).mapFields(
  Struct.evolve({
    a: (field) => Schema.optionalKey(field)
  })
)
```

### Tagged Structs

A tagged struct is a struct that includes a `_tag` field. This field is used to identify the specific variant of the object.

**Example** (Tagged struct as a shorthand for a struct with a `_tag` field)

```ts
import { Schema } from "effect/unstable/schema"

// Defines a struct with a fixed `_tag` field
const tagged = Schema.TaggedStruct("A", {
  a: Schema.String
})

// This is the same as writing:
const equivalent = Schema.Struct({
  _tag: Schema.tag("A"),
  a: Schema.String
})
```

## Tuples

A tuple schema describes a fixed-length array where each position has its own type.

### Rest Elements

You can add rest elements to a tuple using `Schema.TupleWithRest`.

```ts
import { Schema } from "effect/unstable/schema"

export const schema = Schema.TupleWithRest(Schema.Tuple([Schema.FiniteFromString, Schema.String]), [
  Schema.Boolean,
  Schema.String
])

/*
type Type = readonly [number, string, ...boolean[], string]
*/
type Type = typeof schema.Type
```

### Element Annotations

You can annotate elements using the `annotateKey` method.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Tuple([
  Schema.String.annotateKey({
    description: "my element description",
    messageMissingKey: "this element is required"
  })
])
```

### Deriving Tuples

You can map the elements of a tuple schema using the `mapElements` static method.

#### Pick

Use `Tuple.pick` to keep only a selected set of elements.

```ts
import { Schema, Tuple } from "effect/unstable/schema"

const schema = Schema.Tuple([Schema.String, Schema.Number, Schema.Boolean]).mapElements(Tuple.pick([0, 2]))
```

#### Omit

Use `Tuple.omit` to remove specified elements from a tuple.

```ts
import { Schema, Tuple } from "effect/unstable/schema"

const schema = Schema.Tuple([Schema.String, Schema.Number, Schema.Boolean]).mapElements(Tuple.omit([1]))
```

## Arrays

An array schema describes a variable-length list where every element shares the same type.

### Unique Arrays

You can deduplicate arrays using `Schema.UniqueArray`.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.UniqueArray(Schema.String)

console.log(String(Schema.decodeUnknownExit(schema)(["a", "b", "a"])))
// Failure(Cause([Fail(SchemaError: Expected an array with unique items, got ["a","b","a"])]))
```

## Records

A record schema describes an object whose keys are dynamic (not known ahead of time).

### Key Transformations

`Schema.Record` supports transforming keys during decoding and encoding.

**Example** (Transforming snake_case keys to camelCase)

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

const SnakeToCamel = Schema.String.pipe(Schema.decode(SchemaTransformation.snakeToCamel()))

const schema = Schema.Record(SnakeToCamel, Schema.Number)

console.log(Schema.decodeUnknownSync(schema)({ a_b: 1, c_d: 2 }))
// { aB: 1, cD: 2 }
```

### Number Keys

Records with number keys are supported.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Record(Schema.Int, Schema.String)
```

### Mutability

By default, records are tagged as `readonly`. You can mark a record as mutable using `Schema.mutableKey`.

```ts
import { Schema } from "effect/unstable/schema"

export const schema = Schema.Record(Schema.String, Schema.mutableKey(Schema.Number))
```

### Literal Structs

When you pass a union of string literals as the key schema to `Schema.Record`, you get a struct-like schema where each literal becomes a required key.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Record(Schema.Literals(["a", "b"]), Schema.Number)

/*
type Type = {
    readonly a: number;
    readonly b: number;
}
*/
type Type = typeof schema.Type
```

## Unions

A union schema accepts a value if it matches any one of its members.

### Excluding Incompatible Members

If a union member is not compatible with the input, it is automatically excluded during validation.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Union([Schema.NonEmptyString, Schema.Number])

console.log(String(Schema.decodeUnknownExit(schema)("")))
// Failure(Cause([Fail(SchemaError: Expected a value with a length of at least 1, got "")]))
```

### Exclusive Unions

You can create an exclusive union, where the union matches if exactly one member matches, by passing the `{ mode: "oneOf" }` option.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Union([Schema.Struct({ a: Schema.String }), Schema.Struct({ b: Schema.Number })], {
  mode: "oneOf"
})
```

### Union of Literals

You can create a union of literals using `Schema.Literals`.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Literals(["red", "green", "blue"])
```

### Tagged Unions

You can define a tagged union using the `Schema.TaggedUnion` helper.

```ts
import { Schema } from "effect/unstable/schema"

// Create a union of two tagged structs
const schema = Schema.TaggedUnion({
  A: { a: Schema.String },
  B: { b: Schema.Finite }
})
```

This is equivalent to writing:

```ts
const schema = Schema.Union([
  Schema.TaggedStruct("A", { a: Schema.String }),
  Schema.TaggedStruct("B", { b: Schema.Finite })
])
```

## See Also

- [schema-elementary.md](schema-elementary.md) - Primitives, Literals, Strings, Numbers, Dates
- [schema-recursive.md](schema-recursive.md) - Recursive schemas
- [schema-validation.md](schema-validation.md) - Adding runtime checks
