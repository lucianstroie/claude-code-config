---
name: data-type-result
description: Comprehensive reference for Effect Result type - synchronous, pure computations that can succeed or fail. Use when working with Result for explicit error handling, parsing validation, or pure functional pipelines.
---

# Result - Synchronous Error Handling

A synchronous, pure type for representing computations that can succeed (`Success<A>`) or fail (`Failure<E>`). Unlike `Effect`, `Result` is evaluated eagerly and carries no side effects.

## Table of Contents

- [Quickstart](#quickstart)
- [Mental Model](#mental-model)
- [Result vs Option](#result-vs-option)
- [Constructors](#constructors)
- [Type Guards](#type-guards)
- [Getters](#getters)
- [Mapping](#mapping)
- [Sequencing](#sequencing)
- [Error Handling](#error-handling)
- [Filtering](#filtering)
- [Generators](#generators)
- [Do Notation](#do-notation)
- [Transposing](#transposing)
- [Utilities](#utilities)
- [Effect Interoperability](#effect-interoperability)
- [Gotchas](#gotchas)
- [See Also](#see-also)

## Quickstart

A practical example: parsing and validating input with Result.

```ts
import { Result, Option } from "effect";

const parse = (input: string): Result.Result<number, string> =>
  isNaN(Number(input))
    ? Result.fail("not a number")
    : Result.succeed(Number(input));

const ensurePositive = (n: number): Result.Result<number, string> =>
  n > 0 ? Result.succeed(n) : Result.fail("not positive");

const result = Result.flatMap(parse("42"), ensurePositive);

console.log(Result.getOrElse(result, (err) => `Error: ${err}`));
// Output: 42
```

## Mental Model

`Result<A, E>` is a discriminated union: `Success<A, E> | Failure<A, E>`

- `Success` wraps a value of type `A`, accessed via `.success`
- `Failure` wraps an error of type `E`, accessed via `.failure`
- `E` defaults to `never`, so `Result<number>` means a result that cannot fail
- `Result` is yieldable in `Effect.gen`, producing the inner value or short-circuiting on failure
- All operations are pure and return new `Result` values; the input is never mutated

## Result vs Option

| Type           | Use When                                                 |
| -------------- | -------------------------------------------------------- |
| `Option<A>`    | Value may or may not be present (like nullable)          |
| `Result<A, E>` | Computation may succeed or fail with explicit error type |

```ts
// Option - value might be missing
Option.fromNullable(maybeValue);

// Result - computation might fail
Result.try(() => JSON.parse(userInput));
```

## Constructors

### succeed / fail

```ts
import { Result } from "effect";

// Success with a value
const success = Result.succeed(42);

// Failure with an error
const failure = Result.fail("something went wrong");
```

### Pre-built constants

```ts
Result.void; // Result<void> - success with undefined
Result.failVoid; // Result<never, void> - failure with undefined
Result.succeedNone; // Result<Option<never>> - success with None
Result.succeedSome(a); // Result<Option<A>> - success with Some(a)
```

### fromNullishOr

Converts `null` or `undefined` to a `Failure`:

```ts
Result.fromNullishOr(1, () => "fallback"); // Success(1)
Result.fromNullishOr(null, () => "fallback"); // Failure("fallback")
```

### fromOption

Converts `Option<A>` to `Result<A, E>`:

```ts
Result.fromOption(Option.some(1), () => "missing"); // Success(1)
Result.fromOption(Option.none(), () => "missing"); // Failure("missing")
```

### try\_ (try)

Wraps synchronous code that may throw:

```ts
// Simple form - error type is unknown
Result.try(() => JSON.parse('{"name": "Alice"}'));

// With error mapping
Result.try({
  try: () => JSON.parse("not json"),
  catch: (e) => `Parse failed: ${e}`,
});
```

### liftPredicate

Creates a `Result` from a predicate:

```ts
const ensurePositive = (n: number) =>
  Result.liftPredicate(
    (n: number) => n > 0,
    (n) => `${n} is not positive`,
  );

ensurePositive(5); // Success(5)
ensurePositive(-1); // Failure("-1 is not positive")
```

## Type Guards

```ts
Result.isResult(input); // true for Success or Failure
Result.isSuccess(result); // true if Success
Result.isFailure(result); // true if Failure
```

## Getters

### getSuccess / getFailure

Extract as `Option`:

```ts
Result.getSuccess(Result.succeed(42)); // Some(42)
Result.getSuccess(Result.fail("err")); // None
```

### getOrElse

Extract with fallback:

```ts
Result.getOrElse(Result.succeed(1), () => 0); // 1
Result.getOrElse(Result.fail("err"), () => 0); // 0
```

### getOrNull / getOrUndefined

```ts
Result.getOrNull(Result.succeed(1)); // 1
Result.getOrNull(Result.fail("err")); // null

Result.getOrUndefined(Result.succeed(1)); // 1
Result.getOrUndefined(Result.fail("err")); // undefined
```

### getOrThrow / getOrThrowWith

```ts
Result.getOrThrow(Result.succeed(1)); // 1
Result.getOrThrow(Result.fail("err")); // throws "err"

Result.getOrThrowWith(Result.fail("err"), () => new Error(`Unexpected: ${e}`));
```

### merge

Returns `A | E` regardless of variant:

```ts
Result.merge(Result.succeed(42)); // 42
Result.merge(Result.fail("err")); // "err"
```

## Mapping

### map / mapError / mapBoth

```ts
// Transform success
Result.map(Result.succeed(3), (n) => n * 2); // Success(6)

// Transform error
Result.mapError(Result.fail("err"), (e) => `Error: ${e}`); // Failure("Error: err")

// Transform both
Result.mapBoth(Result.succeed(1), {
  onSuccess: (n) => n + 1,
  onFailure: (e) => `Error: ${e}`,
}); // Success(2)
```

## Sequencing

### flatMap

Chain operations that return `Result`:

```ts
import { pipe } from "effect";

pipe(
  Result.succeed(5),
  Result.flatMap((n) =>
    n > 0 ? Result.succeed(n * 2) : Result.fail("not positive"),
  ),
); // Success(10)
```

### andThen

Flexible variant accepting values or functions:

```ts
// Function returning Result (like flatMap)
Result.andThen(Result.succeed(1), (n) => Result.succeed(n + 1));

// Function returning plain value (auto-wrapped)
Result.andThen(Result.succeed(1), (n) => n + 1);

// Constant value
Result.andThen(Result.succeed(1), "done");
```

### all

Collect multiple Results:

```ts
// Tuple
Result.all([Result.succeed(1), Result.succeed("two")]);
// Success([1, "two"])

// Struct
Result.all({ x: Result.succeed(1), y: Result.succeed(2) });
// Success({ x: 1, y: 2 })

// Short-circuits on first failure
Result.all([Result.succeed(1), Result.fail("err")]);
// Failure("err")
```

## Error Handling

### orElse

Recover from failure with a fallback:

```ts
import { pipe } from "effect";

pipe(
  Result.fail("primary failed"),
  Result.orElse(() => Result.succeed(99)),
); // Success(99)
```

### filterOrFail

Validate success value:

```ts
import { pipe } from "effect";

pipe(
  Result.succeed(0),
  Result.filterOrFail(
    (n) => n > 0,
    (n) => `${n} is not positive`,
  ),
); // Failure("0 is not positive")
```

## Generators

Use `yield*` for sequential composition:

```ts
import { Result } from "effect";

const result = Result.gen(function* () {
  const a = yield* Result.succeed(1);
  const b = yield* Result.succeed(2);
  return a + b;
}); // Success(3)
```

Key difference from `Effect.gen`: Result.gen evaluates **eagerly and synchronously**.

## Do Notation

Build objects step by step:

```ts
import { pipe, Result } from "effect";

const result = pipe(
  Result.Do,
  Result.bind("x", () => Result.succeed(2)),
  Result.bind("y", () => Result.succeed(3)),
  Result.let("sum", ({ x, y }) => x + y),
); // Success({ x: 2, y: 3, sum: 5 })
```

## Transposing

Convert between `Option<Result>` and `Result<Option>`:

```ts
import { Option, Result } from "effect";

// Option<Result> -> Result<Option>
Result.transposeOption(Option.some(Result.succeed(42)));
// Success(Some(42))

Result.transposeMapOption(Option.some("42"), (s) =>
  isNaN(Number(s)) ? Result.fail("not a number") : Result.succeed(Number(s)),
);
// Success(Some(42))
```

## Utilities

### flip

Swap success and failure channels:

```ts
Result.flip(Result.succeed(42)); // Failure(42)
Result.flip(Result.fail("err")); // Success("err")
```

### makeEquivalence

Create an `Equivalence` for comparing Results:

```ts
import { Equivalence, Result } from "effect";

const eq = Result.makeEquivalence(
  Equivalence.strictEqual<number>(),
  Equivalence.strictEqual<string>(),
);
```

## Effect Interoperability

Convert between Effect and Result:

```ts
import { Effect, Result } from "effect";

// Effect -> Result
const result = Effect.result(Effect.succeed(42));
// Effect<Result<number, never>>

// Result -> Effect
const effect = Effect.fromResult(Result.succeed(42));
// Effect<number>
```

## Gotchas

- `E` defaults to `never`, so `Result<number>` means a result that cannot fail
- `andThen` accepts more input types than `flatMap` (values, functions, Results)
- `all` short-circuits on the first `Failure`; later elements are not inspected
- `getOrThrow` throws the raw failure value `E`; use `getOrThrowWith` for custom error objects
- Unlike `Effect`, `Result` evaluates eagerly and synchronously

## See Also

- [data-types.md](data-types.md) - Overview of all data types (Option, Chunk, HashSet, etc.)
- [error-handling.md](error-handling.md) - Error handling patterns with Effect
- [core-patterns.md](core-patterns.md) - Effect.gen and Effect.fn patterns
