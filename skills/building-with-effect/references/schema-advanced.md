---
name: schema-advanced
description: Internal type model, type hierarchy, and generic improvements in Effect Schema. For library authors and advanced users.
---

# Advanced Topics

This section covers Schema's internal type machinery and advanced features.

## Table of Contents

- [Model](#model)
  - [Parameter Overview](#parameter-overview)
  - [AST Node Structure](#ast-node-structure)
- [Type Hierarchy](#type-hierarchy)
- [Typed Annotations](#typed-annotations)
- [Separate Requirement Type Parameters](#separate-requirement-type-parameters)

## Model

A "schema" is a strongly typed wrapper around an untyped AST (abstract syntax tree) node.

The base interface is `Bottom`, which sits at the bottom of the schema type hierarchy.

```ts
export interface Bottom<
  out T,
  out E,
  out RD,
  out RE,
  out Ast extends AST.AST,
  out RebuildOut extends Top,
  out TypeMakeIn = T,
  out Iso = T,
  in out TypeParameters extends ReadonlyArray<Top> = readonly [],
  out TypeMake = TypeMakeIn,
  out TypeMutability extends Mutability = "readonly",
  out TypeOptionality extends Optionality = "required",
  out TypeConstructorDefault extends ConstructorDefault = "no-default",
  out EncodedMutability extends Mutability = "readonly",
  out EncodedOptionality extends Optionality = "required"
> extends Pipeable.Pipeable {
  readonly [TypeId]: typeof TypeId

  readonly ast: Ast
  readonly "~rebuild.out": RebuildOut
  readonly "~type.parameters": TypeParameters

  readonly Type: T
  readonly Encoded: E
  readonly DecodingServices: RD
  readonly EncodingServices: RE
}
```

### Parameter Overview

- `T`: the decoded output type
- `E`: the encoded representation
- `RD`: the type of the services required for decoding
- `RE`: the type of the services required for encoding
- `Ast`: the AST node type
- `RebuildOut`: the type returned when modifying the schema

Contextual information about the schema (when used in composite schemas):

- `TypeMake`: the type used to construct the value
- `TypeReadonly`: whether the schema is readonly on the type side
- `TypeIsOptional`: whether the schema is optional on the type side
- `TypeDefault`: whether the constructor has a default value

### AST Node Structure

Every schema is based on an AST node with a consistent internal shape:

- `annotations`: metadata attached to the schema node
- `checks`: an array of validation rules
- `encoding`: a list of transformations that describe how to encode the value
- `context`: includes details used when the schema appears inside composite schemas

## Type Hierarchy

The `Bottom` type is the foundation of the schema system.

Higher-level schema types build on this base by narrowing those parameters:

- `Top`: a generic schema with no fixed shape
- `Schema<T>`: represents the TypeScript type `T`
- `Codec<T, E, RD, RE>`: a schema that decodes `E` to `T` and encodes `T` to `E`

### Best Practices

Use `Top`, `Schema`, and `Codec` as _constraints_ only. Do not use them as explicit annotations or return types.

**Example** (Prefer constraints over wide annotations)

```ts
import { Schema } from "effect/unstable/schema"

// ✅ Use as a constraint. S can be any schema that extends Top.
declare function foo<S extends Schema.Top>(schema: S)

// ❌ Do not return Codec directly. It erases useful type information.
declare function bar(): Schema.Codec<number, string>
```

These wide types reset other internal parameters to defaults, which removes useful information.

## Typed Annotations

You can retrieve typed annotations with the `Annotations.resolveInto` function.

**Example** (Adding a custom annotation for versioning)

```ts
import { Schema } from "effect/unstable/schema"

// Extend the Annotations interface with a custom `version` annotation
declare module "effect/Schema" {
  namespace Annotations {
    interface Augment {
      readonly version?: readonly [major: number, minor: number, patch: number] | undefined
    }
  }
}

// The `version` annotation is now recognized by the TypeScript compiler
const schema = Schema.String.annotate({ version: [1, 2, 0] })

const version = Schema.resolveInto(schema)?.["version"]
```

## Separate Requirement Type Parameters

In real-world applications, decoding and encoding often have different dependencies. For example, decoding may require access to a database, while encoding does not.

To support this, schemas now have two separate requirement parameters:

```ts
interface Codec<T, E, RD, RE> {
  // ...
}
```

- `RD`: services required **only for decoding**
- `RE`: services required **only for encoding**

**Example** (Decoding requirements are ignored during encoding)

```ts
import type { Effect } from "effect"
import { Schema, Context } from "effect/unstable/schema"

// A service that retrieves full user info from an ID
class UserDatabase extends Context.Service<
  UserDatabase,
  {
    getUserById: (id: string) => Effect.Effect<{ readonly id: string; readonly name: string }>
  }
>()("UserDatabase") {}

// Schema that decodes from an ID to a user object using the database,
// but encodes just the ID
declare const User: Schema.Codec<
  { id: string; name: string },
  string,
  UserDatabase, // Decoding requires the database
  never // Encoding does not require any services
>
```

## See Also

- [schema-classes.md](schema-classes.md) - Using Schema.Opaque and Schema.Class
