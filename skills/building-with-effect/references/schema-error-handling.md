---
name: schema-error-handling
description: Format validation errors with hooks, custom messages, and i18n support. Use when presenting user-friendly error messages from Effect Schema validation failures.
---

# Error Handling and Formatting

When validation fails, Schema produces structured error objects that describe what went wrong. Formatters turn those error objects into human-readable messages.

## Table of Contents

- [Formatters](#formatters)
  - [StandardSchemaV1 formatter](#standardschemav1-formatter)
- [Hooks](#hooks)
  - [Customizing messages with hooks](#customizing-messages-with-hooks)
- [Inline custom messages](#inline-custom-messages)
- [Sending a FailureResult over the wire](#sending-a-failureresult-over-the-wire)

## Formatters

### StandardSchemaV1 formatter

The StandardSchemaV1 formatter is used by `Schema.toStandardSchemaV1` and returns a `StandardSchemaV1.FailureResult` object:

```ts
export interface FailureResult {
  readonly issues: ReadonlyArray<Issue>;
}

export interface Issue {
  readonly message: string;
  readonly path: ReadonlyArray<PropertyKey>;
}
```

## Hooks

Formatter hooks let you define custom messages in one place and apply them across different schemas.

There are two kinds of hooks:

- `LeafHook` — for issues that occur at leaf nodes in the schema
- `CheckHook` — for custom validation checks

`LeafHook` handles these issue types:

- `InvalidType`
- `InvalidValue`
- `MissingKey`
- `UnexpectedKey`
- `Forbidden`
- `OneOf`

`CheckHook` handles `Check` issues, such as failed filters / refinements.

**Example** (Default hooks)

```ts
import { Effect, Schema, SchemaIssue } from "effect/unstable/schema";

const schema = Schema.Struct({
  a: Schema.NonEmptyString,
  b: Schema.NonEmptyString,
});

Schema.decodeUnknownEffect(schema)({ b: "" }, { errors: "all" })
  .pipe(
    Effect.mapError((error) =>
      SchemaIssue.makeFormatterStandardSchemaV1()(error.issue),
    ),
    Effect.runPromise,
  )
  .then(console.log, (a) => console.dir(a, { depth: null }));
/*
Output:
{
  issues: [
    { path: [ 'a' ], message: 'Missing key' },
    { path: [ 'b' ], message: 'Expected a value with a length of at least 1, got ""' }
  ]
}
*/
```

### Customizing Messages with Hooks

**Example** (Using hooks to translate common messages)

```ts
import { Schema } from "effect/unstable/schema";

const Person = Schema.Struct({
  name: Schema.String.check(Schema.isNonEmpty()),
});

const logIssues = getLogIssues({
  leafHook: (issue) => {
    switch (issue._tag) {
      case "InvalidType": {
        if (issue.ast._tag === "String") {
          return t("string.mismatch");
        } else if (issue.ast._tag === "Objects") {
          return t("struct.mismatch");
        }
        return t("default.mismatch");
      }
      case "InvalidValue": {
        return t("default.invalidValue");
      }
      case "MissingKey":
        return t("struct.missingKey");
      case "UnexpectedKey":
        return t("struct.unexpectedKey");
      case "Forbidden":
        return t("default.forbidden");
      case "OneOf":
        return t("default.oneOf");
    }
  },
  checkHook: (issue) => {
    const meta = issue.filter.annotations?.meta;
    if (meta) {
      switch (meta._tag) {
        case "isMinLength": {
          return t("string.minLength", { minLength: meta.minLength });
        }
      }
    }
    return t("default.check");
  },
});
```

## Inline Custom Messages

You can attach custom error messages directly to a schema using annotations.

**Example** (Attaching custom messages to a struct field)

```ts
import { Schema } from "effect/unstable/schema";

const Person = Schema.Struct({
  name: Schema.String.annotate({ message: t("string.mismatch") })
    .annotateKey({ messageMissingKey: t("struct.missingKey") })
    .check(
      Schema.isNonEmpty({ message: t("string.minLength", { minLength: 1 }) }),
    ),
}).annotate({ message: t("struct.mismatch") });
```

## Sending a FailureResult over the Wire

You can use the `Schema.StandardSchemaV1FailureResult` schema to send a `StandardSchemaV1.FailureResult` over the wire.

```ts
import { Schema, SchemaIssue, SchemaParser } from "effect/unstable/schema";

const b = Symbol.for("b");

const schema = Schema.Struct({
  a: Schema.NonEmptyString,
  [b]: Schema.Finite,
  c: Schema.Tuple([Schema.String]),
});

const r = SchemaParser.decodeUnknownExit(schema)(
  { a: "", c: [] },
  { errors: "all" },
);

if (r._tag === "Failure") {
  const failures = r.cause.failures;
  if (failures[0]?._tag === "Fail") {
    const failureResult = SchemaIssue.makeFormatterStandardSchemaV1()(
      failures[0].error,
    );
    const serializer = Schema.toCodecJson(Schema.StandardSchemaV1FailureResult);
    console.dir(Schema.encodeSync(serializer)(failureResult), { depth: null });
  }
}
```

## See Also

- [error-handling.md](../error-handling.md) - Schema.TaggedErrorClass for error definitions
