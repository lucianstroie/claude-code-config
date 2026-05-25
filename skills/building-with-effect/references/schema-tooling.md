---
name: schema-tooling
description: Generate JSON Schemas, test data generators, equivalence checks, optics, and differ from schemas. Use when deriving tooling from Effect Schema definitions.
---

# Schema Generation and Tooling

Schema can derive JSON Schemas, test data generators (Arbitraries), equivalence checks, optics, and more from a single schema definition.

## Table of Contents

- [JSON Schema Generation](#json-schema-generation)
  - [Basic Conversion](#basic-conversion)
  - [Attaching Standard Metadata](#attaching-standard-metadata)
  - [Optional fields / elements](#optional-fields--elements)
  - [Defining a JSON-safe representation for custom types](#defining-a-json-safe-representation-for-custom-types)
  - [Validation Constraints](#validation-constraints)
- [Generating an Arbitrary from a Schema](#generating-an-arbitrary-from-a-schema)
  - [Basic Conversion](#basic-conversion-1)
  - [Adding support for Custom Types](#adding-support-for-custom-types)
  - [Overriding the default generated Arbitrary](#overriding-the-default-generated-arbitrary)
- [Generating an Equivalence from a Schema](#generating-an-equivalence-from-a-schema)
- [Generating an Optic from a Schema](#generating-an-optic-from-a-schema)
- [Using the Differ Module for JSON Patches](#using-the-differ-module-for-json-patches)

## JSON Schema Generation

### Generating a JSON Schema from a Schema

#### Basic Conversion

By default, a schema produces a draft-2020-12 JSON Schema.

**Example** (Tuple to draft-2020-12 JSON Schema)

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Tuple([Schema.String, Schema.Finite])
const document = Schema.toJsonSchemaDocument(schema)

console.log(JSON.stringify(document, null, 2))
/*
{
  "source": "draft-2020-12",
  "schema": {
    "type": "array",
    "prefixItems": [
      { "type": "string" },
      { "type": "number" }
    ],
    "maxItems": 2,
    "minItems": 2
  },
  "definitions": {}
}
*/
```

To generate a draft-07 JSON Schema, use `JsonSchema.toDocumentDraft07`.

#### Attaching Standard Metadata

Use `.annotate(...)` to attach standard JSON Schema annotations:

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.NonEmptyString.annotate({
  title: "Username",
  description: "A non-empty user name string",
  default: "anonymous",
  examples: ["alice", "bob"]
})

const document = Schema.toJsonSchemaDocument(schema)
```

#### Optional fields / elements

Optional fields are converted to optional fields or elements in the JSON Schema.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.optionalKey(Schema.String)
})

const document = Schema.toJsonSchemaDocument(schema)
/*
{
  "source": "draft-2020-12",
  "schema": {
    "type": "object",
    "properties": {
      "a": { "type": "string" }
    },
    "additionalProperties": false
  },
  "definitions": {}
}
*/
```

Fields including `undefined` (such as those defined using `Schema.optional` or `Schema.UndefinedOr`) are converted to optional fields with a union with the `null` type.

#### Defining a JSON-safe representation for custom types

This example shows how `Schema.toCodecJson` and `Schema.toJsonSchema` can describe the same JSON shape for a custom type.

**Example** (Align a JSON serializer and JSON Schema for `Headers`)

```ts
import { Schema, SchemaGetter } from "effect/unstable/schema"

const MyHeaders = Schema.instanceOf(Headers, {
  toCodecJson: () =>
    Schema.link<Headers>()(
      Schema.Array(Schema.Tuple([Schema.String, Schema.String])),
      {
        decode: SchemaGetter.transform((headers) => new Headers(headers.map(([key, value]) => [key, value]))),
        encode: SchemaGetter.transform((headers) => [...headers.entries()])
      }
    )
})

const schema = Schema.Struct({ headers: MyHeaders })

// Build a serializer that produces JSON-safe values
const serializer = Schema.toCodecJson(schema)

// Generate a JSON Schema that matches the JSON-safe shape
const document = Schema.toJsonSchemaDocument(schema)
```

#### Validation Constraints

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.String.check(Schema.isMinLength(1))

const document = Schema.toJsonSchemaDocument(schema)
/*
{
  "source": "draft-2020-12",
  "schema": {
    "type": "string",
    "allOf": [{ "minLength": 1 }]
  },
  "definitions": {}
}
*/
```

## Generating an Arbitrary from a Schema

Property-based testing checks your code against many randomly generated inputs. An Arbitrary is a generator that produces random values matching your schema.

#### Basic Conversion

You can convert any non-declaration, non-`never` schema to a Fast-Check `Arbitrary<T>`.

```ts
import { Schema } from "effect/unstable/schema"
import { FastCheck } from "effect/testing"

const schema = Schema.Tuple([Schema.String, Schema.Number])
const arb = Schema.toArbitrary(schema)

console.log(FastCheck.sample(arb, 10))
```

#### Adding support for Custom Types

For a custom type, provide an `arbitrary` annotation.

**Example** (Custom Arbitrary for `URL`)

```ts
import { Schema } from "effect/unstable/schema"
import { FastCheck } from "effect/testing"

const URL = Schema.instanceOf(globalThis.URL, {
  title: "URL",
  arbitrary:
    () => (fc) => fc.webUrl().map((s) => new globalThis.URL(s))
})

console.log(FastCheck.sample(Schema.toArbitrary(URL), 3))
```

#### Overriding the default generated Arbitrary

```ts
import { Schema } from "effect/unstable/schema"
import { FastCheck } from "effect/testing"

// Add an override to restrict numbers to integers 10..20
const schema = Schema.Number.annotate({
  toArbitrary: () => (fc) => fc.integer({ min: 10, max: 20 })
})

console.log(FastCheck.sample(Schema.toArbitrary(schema), 3))
// Example Output: [ 12, 12, 18 ]
```

## Generating an Equivalence from a Schema

An equivalence function checks whether two values are structurally equal according to the schema's definition.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String,
  b: Schema.Number
})

const equivalence = Schema.toEquivalence(schema)
```

#### Providing a custom equivalence for a class

```ts
import { Schema } from "effect/unstable/schema"

class MyClass {
  constructor(readonly a: string) {}
}

const schema = Schema.instanceOf(MyClass, {
  toEquivalence: () => (x, y) => x.a === y.a
})

const equivalence = Schema.toEquivalence(schema)
```

## Generating an Optic from a Schema

Optics provide a composable way to read and update deeply nested values without mutating the original object.

**Example** (Generating an `Iso` automatically from a schema)

```ts
import { Schema } from "effect/unstable/schema"

class A extends Schema.Class<A>("A")({ s: Schema.String }) {}
class B extends Schema.Class<B>("B")({ a: A }) {}

// Automatically generate an Iso from the schema of B
const iso = Schema.toIso(B)

const _s = iso.key("a").key("s")

console.log(_s.replace("b", new B({ a: new A({ s: "a" }) })))
// B { a: A { s: 'b' } }
```

## Using the Differ Module for JSON Patches

The `Differ` module lets you compute and apply JSON Patch (RFC 6902) changes.

**Example** (Compare two values and apply the patch)

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  id: Schema.Number,
  name: Schema.String,
  price: Schema.Number
})

const differ = Schema.toDifferJsonPatch(schema)

const oldValue = { id: 1, name: "a", price: 1 }
const newValue = { id: 1, name: "b", price: 2 }

const jsonPatch = differ.diff(oldValue, newValue)
console.log(jsonPatch)
/*
[
  { op: 'replace', path: '/name', value: 'b' },
  { op: 'replace', path: '/price', value: 2 }
]
*/

const patched = differ.patch(oldValue, jsonPatch)
console.log(patched)
// { id: 1, name: 'b', price: 2 }
```

## See Also

- [schema-serialization.md](schema-serialization.md) - JSON serialization with toCodecJson
