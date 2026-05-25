---
name: schema-representation
description: Convert schemas to portable documents for storage, network transmission, or code generation. Use when serializing or generating code from Effect Schema.
---

# Schema Representation

The `SchemaRepresentation` module converts a `Schema` into a portable data structure and back again.

## Table of Contents

- [Overview](#overview)
- [The data model](#the-data-model)
  - [Representation](#representation)
  - [Document](#document)
  - [MultiDocument](#multidocument)
- [Limitations](#limitations)
  - [Transformations are not supported](#transformations-are-not-supported)
  - [Only built-in checks can be represented](#only-built-in-checks-can-be-represented)
  - [Annotations are filtered](#annotations-are-filtered)
  - [Declarations need a reviver](#declarations-need-a-reviver)
- [JSON round-tripping](#json-round-tripping)
- [Rebuilding runtime schemas](#rebuilding-runtime-schemas)
- [JSON Schema output](#json-schema-output)
- [Code generation](#code-generation)

## Overview

Use SchemaRepresentation when you need to:

- store schemas on disk (for example in a cache)
- send schemas over the network
- rebuild runtime schemas later
- convert to JSON Schema (Draft 2020-12)
- generate TypeScript code that recreates schemas

At a high level:

- `fromAST` / `fromASTs` turn a schema AST into a `Document` / `MultiDocument`
- `DocumentFromJson` round-trip that document through JSON
- `toSchema` rebuilds a runtime `Schema` from the stored representation
- `toJsonSchemaDocument` produces a Draft 2020-12 JSON Schema document
- `toCodeDocument` prepares data for code generation

## The data model

### Representation

A `Representation` is a tagged object tree (`_tag` fields like `"String"`, `"Objects"`, `"Union"`, ...). It describes the _structure_ of a schema in a JSON-friendly way.

Only a subset of schema features can be represented. See "Limitations" below.

### Document

A `Document` has:

- `representation`: the root `Representation`
- `references`: a map of named definitions used by the root representation

References let the representation share definitions and support recursion.

### MultiDocument

A `MultiDocument` stores multiple root representations that share the same `references` table.

This is useful if you want to serialize a set of schemas together, or if you want to generate code for multiple schemas while emitting shared definitions only once.

## Limitations

`SchemaRepresentation` is meant for schemas that can be described without user code.

### Transformations are not supported

The representation format describes the schema's _shape_ and a set of known checks. It does not store transformation logic.

Schemas that rely on transformations cannot be round-tripped, including:

- `Schema.transform(...)`
- `Schema.encodeTo(...)`
- custom codecs or any schema that changes how values are encoded/decoded

### Only built-in checks can be represented

Only checks that match the built-in meta definitions are supported, such as:

- string checks: `isMinLength`, `isPattern`, `isUUID`, ...
- number checks: `isInt`, `isBetween`, `isMultipleOf`, ...
- array checks: `isLength`, `isUnique`, ...
- object checks: `isMinProperties`, ...

Custom predicates (for example `Schema.filter((x) => ...)`) are not supported.

### Annotations are filtered

Annotations are stored as a record, but only values that look like JSON primitives are kept.

In practice, documentation annotations like `title` and `description` are preserved, while complex values are ignored.

### Declarations need a reviver

Some runtime schemas are represented as `Declaration` nodes. Rebuilding them requires a "reviver" function.

`toSchema` ships with a default reviver (`toSchemaDefaultReviver`) that recognizes a fixed set of constructors.

## JSON round-tripping

### `toJson` / `fromJson`

- `toJson(document)` returns JSON-compatible data (safe to `JSON.stringify`)
- `fromJson(unknown)` validates and parses JSON data back into a `Document`

## Rebuilding runtime schemas

### `toSchema`

`toSchema(document)` walks the representation tree and recreates a runtime schema.

What it does:

- rebuilds the structural schema nodes (`Struct`, `Tuple`, `Union`, ...)
- resolves references from `document.references`
- supports recursive references using `Schema.suspend`
- re-attaches stored annotations via `.annotate(...)` and `.annotateKey(...)`
- re-applies supported checks via `.check(...)`

```ts
SchemaRepresentation.toSchema(document, {
  reviver: (declaration, recur) => {
    // Return a runtime schema to override how a Declaration is rebuilt
    return undefined
  }
})
```

## JSON Schema output

### `toJsonSchemaDocument` / `toJsonSchemaMultiDocument`

These functions convert a `Document` or `MultiDocument` into a Draft 2020-12 JSON Schema document.

## Code generation

### `toCodeDocument`

`toCodeDocument` converts a `MultiDocument` into a structure that is convenient for generating TypeScript source.

It:

- sorts references so non-recursive definitions can be emitted in dependency order
- keeps recursive definitions separate (they must be emitted using `Schema.suspend`)
- sanitizes reference names into valid JavaScript identifiers
- collects extra artifacts that must be emitted (enums, symbols, imports)

## See Also

- [schema-tooling.md](schema-tooling.md) - JSON Schema generation
- [schema-serialization.md](schema-serialization.md) - Serialization formats
