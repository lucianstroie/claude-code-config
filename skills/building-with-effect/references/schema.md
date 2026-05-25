---
name: schema
description: Quick-start guide and index for Effect Schema - type-safe parsing, validation, and transformation.
---

# Schema - Quick Start & Index

Type-safe parsing, validation, and transformation with Effect Schema v4.

See related examples in [effect-smol/ai-docs/src/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/)

> **Important:** Schema is in `effect/unstable/schema`. APIs may change in minor releases until stabilized.

## Table of Contents

- [Quick Start](#quick-start)
- [Topic Index](#topic-index)
- [See Also](#see-also)

## Quick Start

**Define and parse a schema**

```ts
import { Schema } from "effect/unstable/schema";

const User = Schema.Struct({
  id: Schema.Number,
  name: Schema.String,
  email: Schema.String,
});

type User = typeof User.Type;

// Decode
const result = yield * Schema.decode(User)(unknown);

// Decode unknown (safe)
const parseUser = Schema.decodeUnknown(User);
const result = yield * parseUser(input);
```

**Validate primitives**

```ts
// String validation (v4: check method)
Schema.String.check(Schema.isMinLength(1));
Schema.String.check(Schema.isPattern(/^[a-z]+$/));
Schema.String.check(Schema.isUUID());

// Number validation
Schema.Number.check(Schema.isBetween({ minimum: 5, maximum: 10 }));
Schema.Number.check(Schema.isInt());
```

**Define structs with optional fields**

```ts
const User = Schema.Struct({
  id: Schema.Number,
  name: Schema.String,
  email: Schema.optionalKey(Schema.String),  // can be absent
  phone: Schema.optional(Schema.String),      // undefined allowed
  tags: Schema.mutableKey(Schema.Array(Schema.String)),  // writable
});
```

**Transform between types**

```ts
import { Schema, SchemaGetter } from "effect/unstable/schema";

// Date from string
const DateFromString = Schema.Date.pipe(
  Schema.encodeTo(Schema.String, {
    decode: SchemaGetter.Date(),
    encode: SchemaGetter.String(),
  }),
);
```

**Create branded/opaque types**

```ts
class UserId extends Schema.Opaque<UserId>()(
  Schema.String.check(Schema.isUUID()),
) {}

const id = UserId.make("550e8400-e29b-41d4-a716-446655440000");
```

## Schema API Cheat Sheet

Choose the right Schema API based on your use case:

| Scenario | API | Returns |
|----------|-----|---------|
| Validate unknown input (API boundary) | `Schema.decodeUnknownEffect(schema)(data)` | `Effect<A, ParseError>` |
| Transform typed input | `Schema.encodeEffect(schema)(data)` | `Effect<A, ParseError>` |
| Validate typed input (internal) | `Schema.decode(schema)(data)` | `A` (throws on error) |
| Validate and transform | `Schema.transformResult` | `Either<A, ParseError>` |

### When to Use Each API

**For unknown input at API boundaries:**

```ts
// Good — handle unknown data from external source
const parseRequest = (data: unknown) =>
  Schema.decodeUnknownEffect(UserSchema)(data);

// Input: unknown (from JSON.parse, API response, etc.)
// Output: Effect<User, Schema.ParseError>
```

**For typed input transformation:**

```ts
// Good — transform typed data to another schema
const encodeForStorage = (user: User) =>
  Schema.encodeEffect(StoredUserSchema)(user);

// Input: User (typed)
// Output: Effect<StoredUser, Schema.ParseError>
```

**For internal validation (rarely needed):**

```ts
// ⚠️ Use only when you know the input is already typed
const validate = (data: User) => Schema.decode(UserSchema)(data);
// Throws on failure, returns User directly
```

### Effect-based vs Direct APIs

| API | Failure Mode | Use Case |
|-----|--------------|----------|
| `decodeUnknownEffect` | Returns `Effect.fail(ParseError)` | Composable, works with `catchTags` |
| `decodeUnknown` | Returns `Either` | Synchronous, no Effect context needed |
| `decode` | Throws | Quick scripts, internal guards |
| `encodeEffect` | Returns `Effect.fail(ParseError)` | Composable encoding with error handling |

### Common Pattern: API Boundary

```ts
class ValidationError extends Schema.TaggedErrorClass<ValidationError>()(
  "ValidationError",
  { message: Schema.String },
) {}

// Handle unknown input from API
export const processApiRequest = Effect.fn("processApiRequest")(
  function* (rawData: unknown) {
    const data = yield* Schema.decodeUnknownEffect(RequestSchema)(rawData).pipe(
      Effect.mapError((e) => new ValidationError({ message: String(e) })),
    );
    // Use validated data...
    return process(data);
  },
);
```

### v4 API Changes

In Effect v4, the Schema API has been streamlined:

```ts
// v4 style - effect-based
const result = yield* Schema.decodeUnknownEffect(schema)(data);

// v4 style - encode to different schema
const encoded = yield* Schema.encodeEffect(OutputSchema)(input);
```

---

## Topic Index

| Topic | File |
|-------|------|
| Primitives, Literals, Strings, Numbers, Dates, Template Literals | [schema-elementary.md](schema-elementary.md) |
| Structs, Tuples, Arrays, Records, Unions | [schema-composite.md](schema-composite.md) |
| Recursive schemas, suspend | [schema-recursive.md](schema-recursive.md) |
| declare, declareConstructor | [schema-custom-types.md](schema-custom-types.md) |
| Filters, refinements, branding | [schema-validation.md](schema-validation.md) |
| make, defaults | [schema-constructors.md](schema-constructors.md) |
| decodeTo/encodeTo, SchemaTransformation | [schema-transformations.md](schema-transformations.md) |
| Schema.flip | [schema-flipping.md](schema-flipping.md) |
| Opaque, Class, TaggedClass, ErrorClass, TaggedErrorClass | [schema-classes.md](schema-classes.md) |
| JSON, FormData, URLSearchParams, XML codecs | [schema-serialization.md](schema-serialization.md) |
| JSON Schema, Arbitraries, Equivalence, Optics, Differ | [schema-tooling.md](schema-tooling.md) |
| Portable representation, AST | [schema-representation.md](schema-representation.md) |
| Formatters, hooks, i18n | [schema-error-handling.md](schema-error-handling.md) |
| catchDecoding, fallbacks | [schema-middlewares.md](schema-middlewares.md) |
| Type model, hierarchy | [schema-advanced.md](schema-advanced.md) |
| TanStack Form, Elysia | [schema-integrations.md](schema-integrations.md) |

## See Also

- [error-handling.md](error-handling.md) - Schema.TaggedErrorClass for error definitions
- [core-patterns.md](core-patterns.md) - Effect+Schema patterns

