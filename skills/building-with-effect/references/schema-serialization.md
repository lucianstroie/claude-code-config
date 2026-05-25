---
name: schema-serialization
description: Serialize to JSON, FormData, URLSearchParams, and XML with canonical codecs. Use when converting schema values to/from external formats.
---

# Serialization

Serialization converts typed values into a format suitable for storage or transmission (such as JSON, FormData, or XML).

## Table of Contents

- [JSON Support](#json-support)
- [FormData Support](#formdata-support)
- [URLSearchParams Support](#urlsearchparams-support)
- [Canonical Codecs](#canonical-codecs)
  - [JSON Canonical Codec](#json-canonical-codec)
  - [StringTree Canonical Codec](#stringtree-canonical-codec)
  - [ISO Canonical Codec](#iso-canonical-codec)
- [XML Encoder](#xml-encoder)

## JSON Support

#### UnknownFromJsonString

A schema that decodes a JSON-encoded string into an unknown value.

```ts
import { Schema } from "effect/unstable/schema"

Schema.decodeUnknownSync(Schema.UnknownFromJsonString)(`{"a":1,"b":2}`)
// => { a: 1, b: 2 }
```

#### fromJsonString

Returns a schema that decodes a JSON string and then decodes the parsed value using the given schema.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({ a: Schema.Number })
const schemaFromJsonString = Schema.fromJsonString(schema)

Schema.decodeUnknownSync(schemaFromJsonString)(`{"a":1,"b":2}`)
// => { a: 1 }
```

## FormData Support

`Schema.fromFormData` returns a schema that reads a `FormData` instance and decodes it using the provided schema.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.fromFormData(
  Schema.Struct({
    a: Schema.String
  })
)

const formData = new FormData()
formData.append("a", "1")
formData.append("b", "2")

console.log(String(Schema.decodeUnknownExit(schema)(formData)))
// Success({"a":"1"})
```

### Nested fields

Express nested values using bracket notation.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.fromFormData(
  Schema.Struct({
    a: Schema.String,
    b: Schema.Struct({
      c: Schema.String,
      d: Schema.String
    })
  })
)

const formData = new FormData()
formData.append("a", "1")
formData.append("b[c]", "2")
formData.append("b[d]", "3")

console.log(String(Schema.decodeUnknownExit(schema)(formData)))
// Success({"a":"1","b":{"c":"2","d":"3"}})
```

## URLSearchParams Support

`Schema.fromURLSearchParams` returns a schema that reads a `URLSearchParams` instance.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.fromURLSearchParams(
  Schema.Struct({
    a: Schema.String
  })
)

const urlSearchParams = new URLSearchParams("a=1&b=2")

console.log(String(Schema.decodeUnknownExit(schema)(urlSearchParams)))
// Success({"a":"1"})
```

## Canonical Codecs

Canonical codecs turn one schema into another schema (a "codec") that can serialize and deserialize values using a specific format (JSON, strings, `URLSearchParams`, `FormData`, and so on).

### JSON Canonical Codec

Many JavaScript values cannot be serialized to JSON in a safe and reversible way:

- `Date`: `JSON.stringify()` converts a date to an ISO string, but `JSON.parse()` does not restore a `Date` object
- `Uint8Array`, `ReadonlyMap`, `ReadonlySet`: `JSON.stringify()` converts them to `{}`
- `Symbol`, `BigInt`: `JSON.stringify()` throws errors
- Custom classes: `JSON.stringify()` does not know how to encode or decode them

**The solution**: A canonical codec describes how values that match a schema should be converted to JSON using the `toCodecJson` annotation.

**Example** (Encoding a class as a JSON tuple)

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

class Point {
  constructor(public readonly x: number, public readonly y: number) {}

  distance(other: Point): number {
    const dx = this.x - other.x
    const dy = this.y - other.y
    return Math.sqrt(dx * dx + dy * dy)
  }
}

const PointSchema = Schema.instanceOf(Point, {
  toCodecJson: () =>
    Schema.link<Point>()(
      Schema.Tuple([Schema.Finite, Schema.Finite]),
      SchemaTransformation.transform({
        decode: (args) => new Point(...args),
        encode: (instance) => [instance.x, instance.y] as const
      })
    )
})

// Convert the schema into a JSON codec schema
const codecJson = Schema.toCodecJson(PointSchema)

// Encoding produces JSON-safe data
console.log(JSON.stringify(Schema.encodeUnknownSync(codecJson)(new Point(1, 2))))
// "[1,2]"

// Decoding rebuilds the Point instance
console.log(Schema.decodeUnknownSync(codecJson)(JSON.parse("[1,2]")))
// Point { x: 1, y: 2 }
```

### StringTree Canonical Codec

The `StringTree` codec converts all values to strings.

```ts
const toCodecStringTree = Schema.toCodecStringTree(PointSchema)

const stringTree = Schema.encodeUnknownSync(toCodecStringTree)(point)

// every leaf value becomes a string
console.log(stringTree)
// [ '1', '2' ]
```

#### keepDeclarations: true

The `keepDeclarations: true` option does not convert declarations without a `toCodecJson` annotation to `undefined`. This is useful when encoding to `FormData` and you want to preserve `Blob` values.

```ts
import { Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.instanceOf(URL),
  b: Schema.Number
})

const stringTree = Schema.toCodecStringTree(schema, { keepDeclarations: true })

console.log(
  Schema.encodeUnknownSync(stringTree)({
    a: new URL("https://effect.website"),
    b: 1
  })
)
// { a: URL("https://effect.website"), b: '1' }
```

### ISO Canonical Codec

The ISO canonical codec (`toCodecIso`) converts schemas to their `Iso` representation.

```ts
import { Schema } from "effect/unstable/schema"

class Person extends Schema.Class<Person>("Person")({
  name: Schema.String,
  age: Schema.Number
}) {}

const codecIso = Schema.toCodecIso(Person)

const person = new Person({ name: "John", age: 30 })

const serialized = Schema.encodeUnknownSync(codecIso)(person)
console.log(serialized)
// { name: 'John', age: 30 }

const deserialized = Schema.decodeUnknownSync(codecIso)(serialized)
console.log(deserialized)
// Person { name: 'John', age: 30 }
```

## XML Encoder

`Schema.toEncoderXml` lets you serialize values to XML.

```ts
import { Effect, Option, Schema } from "effect/unstable/schema"

const schema = Schema.Struct({
  a: Schema.String,
  b: Schema.Array(Schema.NullOr(Schema.String)),
  c: Schema.Struct({
    d: Schema.Option(Schema.String),
    e: Schema.Date
  }),
  f: Schema.optional(Schema.String)
})

const xmlEncoder = Schema.toEncoderXml(schema)

console.log(
  Effect.runSync(
    xmlEncoder({
      a: "",
      b: ["bar", "baz", null],
      c: { d: Option.some("qux"), e: new Date("2021-01-01") },
      f: undefined
    })
  )
)
/*
<root>
  <a></a>
  <b>
    <item>bar</item>
    <item>baz</item>
    <item/>
  </b>
  <c>
    <d>
      <_tag>Some</_tag>
      <value>qux</value>
    </d>
    <e>2021-01-01T00:00:00.000Z</e>
  </c>
  <f/>
</root>
*/
```

## See Also

- [schema-classes.md](schema-classes.md) - toCodecJson for custom classes
- [schema-tooling.md](schema-tooling.md) - JSON Schema generation from schemas
