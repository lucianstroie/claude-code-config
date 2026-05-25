---
name: schema-classes
description: Define nominal types with Schema.Opaque, Schema.Class, Schema.TaggedClass, Schema.ErrorClass, and Schema.TaggedErrorClass. Use when creating distinct TypeScript types.
---

# Classes and Opaque Types

Schema supports two kinds of nominal types: _opaque structs_ for lightweight distinct types, and _classes_ for full-featured types with methods and equality.

## Table of Contents

- [Opaque Structs](#opaque-structs)
  - [Static methods](#static-methods)
  - [Annotations and filters](#annotations-and-filters)
  - [Recursive Opaque Structs](#recursive-opaque-structs)
  - [Branded Opaque Structs](#branded-opaque-structs)
- [Classes](#classes)
  - [Existing Classes](#existing-classes)
  - [Class with Schema.Class](#class-with-schemaclass)

> **See also**: For TaggedErrorClass usage in error handling, see [error-handling.md](error-handling.md)

## Opaque Structs

Goal: opaque typing without changing runtime behavior.

`Schema.Opaque` lets you take an ordinary `Schema.Struct` and wrap it in a thin class shell whose **only** purpose is to create a distinct TypeScript type.

Internally the value is **still the same plain struct schema**.

Instance methods and custom constructors **are not allowed** in opaque structs.

### How is this different from `Schema.Class`?

`Schema.Class` also wraps a `Struct`, **but** it turns the wrapper into a proper class:

- You can add instance methods, getters, setters, custom constructors.
- The generated class automatically implements `Equal` so structural equality works out of the box.
- Instances carry the class prototype at runtime, so `instanceof` checks succeed and methods are callable.

### Creating an Opaque Struct

**Example** (Creating an Opaque Struct)

```ts
import { Schema } from "effect/unstable/schema"

class Person extends Schema.Opaque<Person>()(
  Schema.Struct({
    name: Schema.String
  })
) {}

//      ┌─── Codec<Person, { readonly name: string; }, never, never>
//      ▼
const codec = Schema.revealCodec(Person)

// const person: Person
const person = Person.make({ name: "John" })

console.log(person.name)
// "John"

// The class itself holds the original schema and its metadata
console.log(Person)
// -> [Function: Person] Struct$

// { readonly name: Schema.String }
Person.fields

const another = Schema.Struct({ name: Person })
```

### Static methods

You can add static members to an opaque struct class to extend its behavior.

**Example** (Custom serializer via static method)

```ts
import { Schema } from "effect/unstable/schema"

class Person extends Schema.Opaque<Person>()(
  Schema.Struct({
    name: Schema.String,
    createdAt: Schema.Date
  })
) {
  static readonly serializer = Schema.toCodecJson(this)
}

console.log(
  Schema.encodeUnknownSync(Person)({
    name: "John",
    createdAt: new Date()
  })
)
// { name: 'John', createdAt: 2025-05-02T13:49:29.926Z }
```

### Annotations and filters

You can attach filters and annotations to the struct passed into `Opaque`.

**Example** (Applying a filter and title annotation)

```ts
import { Schema } from "effect/unstable/schema"

class Person extends Schema.Opaque<Person>()(
  Schema.Struct({
    name: Schema.String
  }).annotate({ identifier: "Person" })
) {}

console.log(String(Schema.decodeUnknownExit(Person)(null)))
// Failure(Cause([Fail(SchemaError: Expected Person, got null)]))
```

### Recursive Opaque Structs

**Example** (Recursive Opaque Struct with Same Encoded and Type)

```ts
import { Schema } from "effect/unstable/schema"

export class Category extends Schema.Opaque<Category>()(
  Schema.Struct({
    name: Schema.String,
    children: Schema.Array(Schema.suspend((): Schema.Codec<Category> => Category))
  })
) {}

/*
type Encoded = {
    readonly children: readonly Category[];
    readonly name: string;
}
*/
export type Encoded = (typeof Category)["Encoded"]
```

**Example** (Mutually Recursive Schemas)

```ts
import { Schema } from "effect/unstable/schema"

class Expression extends Schema.Opaque<Expression>()(
  Schema.Struct({
    type: Schema.Literal("expression"),
    value: Schema.Union([Schema.Number, Schema.suspend((): Schema.Codec<Operation> => Operation)])
  })
) {}

class Operation extends Schema.Opaque<Operation>()(
  Schema.Struct({
    type: Schema.Literal("operation"),
    operator: Schema.Literals(["+", "-"]),
    left: Expression,
    right: Expression
  })
) {}
```

### Branded Opaque Structs

You can brand an opaque struct using the `Brand` generic parameter.

**Example** (Branded Opaque Struct)

```ts
import { Schema } from "effect/unstable/schema"

class A extends Schema.Opaque<A, { readonly brand: unique symbol }>()(
  Schema.Struct({ a: Schema.String })
) {}
class B extends Schema.Opaque<B, { readonly brand: unique symbol }>()(
  Schema.Struct({ a: Schema.String })
) {}

const f = (a: A) => a
const g = (b: B) => b

f(A.make({ a: "a" })) // ok
g(B.make({ a: "a" })) // ok

f(B.make({ a: "a" })) // error: Argument of type 'B' is not assignable to parameter of type 'A'.
g(A.make({ a: "a" })) // error: Argument of type 'A' is not assignable to parameter of type 'B'.
```

## Classes

### Existing Classes

#### Validating the Constructor

**Use Case**: When you want to validate the constructor arguments of an existing class.

**Example** (Using a tuple to validate the constructor arguments)

```ts
import { Schema } from "effect/unstable/schema"

const PersonConstructorArguments = Schema.Tuple([Schema.String, Schema.Finite])

class Person {
  constructor(readonly name: string, readonly age: number) {
    PersonConstructorArguments.make([name, age])
  }
}

try {
  new Person("John", NaN)
} catch (error) {
  if (error instanceof Error) {
    console.log(error.message)
  }
}
/*
Expected a finite number, got NaN
  at [1]
*/
```

### Class with Schema.Class

`Schema.Class` creates a proper class with methods and equality.

**Example** (Defining a Schema Class)

```ts
import { Schema, SchemaTransformation } from "effect/unstable/schema"

class Person extends Schema.Class<Person>("Person")({
  name: Schema.String,
  age: Schema.Number
}) {
  greet() {
    return `Hello, ${this.name}!`
  }
}

const person = Person.make({ name: "John", age: 30 })
console.log(person.greet())
// Hello, John!

// Equality works out of the box
const another = Person.make({ name: "John", age: 30 })
console.log(person === another)
// false (different instances, but equal values)
```

## See Also

- [error-handling.md](error-handling.md) - Schema.TaggedErrorClass for error definitions
- [core-patterns.md](core-patterns.md) - Effect+Schema patterns
