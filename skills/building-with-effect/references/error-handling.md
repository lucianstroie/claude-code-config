# Error Handling

Error management strategies with Effect using Schema.TaggedErrorClass.

## Contents

- [Overview](#overview) - Error handling philosophy
- [Defining Errors](#defining-errors) - Schema.TaggedErrorClass patterns
- [Catching Errors](#catching-errors) - catchTag, catchTags, catchReason
- [Error Recovery](#error-recovery) - orElse, retry, timeout
- [Error Transformation](#error-transformation) - mapError, absorb
- [Error Inspection](#error-inspection) - Cause operations
- [Error in Effect.fn](#error-in-effectfn) - Handling in function definitions
- [Common Patterns](#common-patterns) - Validation, recovery chains
- [Best Practices](#best-practices) - Recommendations
- [Quick Reference](#quick-reference) - Common operations

## Overview

In Effect, errors are defined using `Schema.TaggedErrorClass` which provides:

- Type-safe error definitions
- Automatic `_tag` field for error identification
- Schema validation for error properties
- Better error serialization

## Defining Errors

> **See also**: [schema-classes.md](schema-classes.md) for Schema.Class, Schema.TaggedClass, and Schema.TaggedErrorClass definitions.

### TaggedErrorClass

```ts
import { Effect, Schema } from "effect";

// Define custom errors using Schema.TaggedErrorClass
export class ParseError extends Schema.TaggedErrorClass<ParseError>()(
  "ParseError",
  {
    input: Schema.String,
    message: Schema.String,
  },
) {}

export class ReservedPortError extends Schema.TaggedErrorClass<ReservedPortError>()(
  "ReservedPortError",
  { port: Schema.Number },
) {}

export class NetworkError extends Schema.TaggedErrorClass<NetworkError>()(
  "NetworkError",
  { statusCode: Schema.Number },
) {}

// Error without additional fields
export class MissingValueError extends Schema.TaggedErrorClass<MissingValueError>()(
  "MissingValueError",
  {},
) {}
```

### Error with Defect Cause

```ts
export class DatabaseError extends Schema.TaggedErrorClass<DatabaseError>()(
  "DatabaseError",
  { cause: Schema.Defect },
) {}

// Usage in try/catch
Effect.try({
  try: () => riskyOperation(),
  catch: (cause) => new DatabaseError({ cause }),
});
```

### Error with Union Types (Reasons)

Define nested error hierarchies for granular error handling:

```ts
class RateLimitError extends Schema.TaggedErrorClass<RateLimitError>()(
  "RateLimitError",
  { retryAfter: Schema.Number },
) {}

class QuotaExceededError extends Schema.TaggedErrorClass<QuotaExceededError>()(
  "QuotaExceededError",
  { limit: Schema.Number },
) {}

class SafetyBlockedError extends Schema.TaggedErrorClass<SafetyBlockedError>()(
  "SafetyBlockedError",
  { category: Schema.String },
) {}

export class AiError extends Schema.TaggedErrorClass<AiError>()("AiError", {
  reason: Schema.Union(RateLimitError, QuotaExceededError, SafetyBlockedError),
}) {}
```

## Catching Errors

### catchTag

Handle specific tagged errors:

```ts
declare const loadPort: (
  input: string,
) => Effect.Effect<number, ParseError | ReservedPortError>;

// Catch multiple errors with one handler
export const recovered = loadPort("80").pipe(
  Effect.catchTag(["ParseError", "ReservedPortError"], () =>
    Effect.succeed(3000),
  ),
);

// Catch specific error first, then all others
export const withFinalFallback = loadPort("invalid").pipe(
  Effect.catchTag("ReservedPortError", () => Effect.succeed(3000)),
  Effect.catch(() => Effect.succeed(3000)),
);
```

### catchTags

Handle multiple errors with different handlers:

```ts
class ValidationError extends Schema.TaggedErrorClass<ValidationError>()(
  "ValidationError",
  { message: Schema.String },
) {}

class NetworkError extends Schema.TaggedErrorClass<NetworkError>()(
  "NetworkError",
  { statusCode: Schema.Number },
) {}

declare const fetchUser: (
  id: string,
) => Effect.Effect<string, ValidationError | NetworkError>;

export const userOrFallback = fetchUser("123").pipe(
  Effect.catchTags({
    ValidationError: (error) =>
      Effect.succeed(`Validation failed: ${error.message}`),
    NetworkError: (error) =>
      Effect.succeed(`Network request failed with status ${error.statusCode}`),
  }),
);
```

### catchReason / catchReasons

Handle errors with nested reason types:

```ts
// Catch a specific reason
export const handleOneReason = callModel.pipe(
  Effect.catchReason(
    "AiError", // Parent error tag
    "RateLimitError", // Reason tag to catch
    (reason) => Effect.succeed(`Retry after ${reason.retryAfter} seconds`),
    (reason) => Effect.succeed(`Model call failed for reason: ${reason._tag}`),
  ),
);

// Catch multiple reasons
export const handleMultipleReasons = callModel.pipe(
  Effect.catchReasons("AiError", {
    RateLimitError: (reason) =>
      Effect.succeed(`Retry after ${reason.retryAfter} seconds`),
    QuotaExceededError: (reason) =>
      Effect.succeed(`Quota exceeded at ${reason.limit} tokens`),
  }),
);
```

### unwrapReason

Move reasons into the error channel for handling with catchTags:

```ts
export const unwrapAndHandle = callModel.pipe(
  Effect.unwrapReason("AiError"),
  Effect.catchTags({
    RateLimitError: (reason) =>
      Effect.succeed(`Back off for ${reason.retryAfter} seconds`),
    QuotaExceededError: (reason) =>
      Effect.succeed(`Increase quota beyond ${reason.limit}`),
    SafetyBlockedError: (reason) =>
      Effect.succeed(`Blocked by safety category: ${reason.category}`),
  }),
);
```

### catch

Handle all errors:

```ts
effect.pipe(Effect.catch((error) => Effect.succeed(`recovered: ${error}`)));
```

### catchCause

Handle full cause chain:

```ts
effect.pipe(
  Effect.catchCause((cause) => Effect.succeed("recovered from cause")),
);
```

## Error Recovery

### orElse / orElseFail

```ts
// Provide fallback effect
const withFallback = primary.pipe(
  Effect.orElse(() => secondary),
  Effect.orElse(() => tertiary),
  Effect.orElse(() => Effect.succeed(defaultValue)),
);

// Fail with specific error if primary fails
const orFail = primary.pipe(Effect.orElseFail(() => new CustomError()));
```

### retry

Retry with schedule:

```ts
import { Schedule } from "effect";

const withRetry = fetchUser("123").pipe(
  Effect.retry({
    times: 3,
    schedule: Schedule.exponential("100 millis"),
  }),
);
```

### timeout

```ts
const withTimeout = longOperation.pipe(
  Effect.timeout("30 seconds"),
  Effect.catchTag("TimeoutError", () => Effect.succeed("timeout")),
);
```

## Error Transformation

### mapError

Transform error type:

```ts
effect.pipe(Effect.mapError((error) => new CustomError(error)));
```

### mapErrorCause

Transform full cause:

```ts
effect.pipe(Effect.mapErrorCause((cause) => new CustomError(cause)));
```

### absorb / absorbWith

```ts
// Convert all errors to defects
const absorbed = effect.pipe(Effect.absorb);

// With custom handler
const absorbedWith = effect.pipe(
  Effect.absorbWith((error) => new CustomError(error)),
);
```

## Error Inspection

### Cause

In v4, `Cause<E>` has been flattened:

```ts
// Structure is now:
interface Cause<E> {
  readonly reasons: ReadonlyArray<Reason<E>>;
}
type Reason<E> = Fail<E> | Die | Interrupt;
```

### Cause Operations

```ts
import { Cause } from "effect";

// Check for specific reason types
Cause.isFailReason(reason);
Cause.isDieReason(reason);
Cause.isInterruptReason(reason);

// Check cause contents
Cause.hasFails(cause);
Cause.hasDies(cause);
Cause.hasInterrupts(cause);

// Find specific errors
Cause.findErrorOption(cause); // Option<E>
Cause.findError(cause); // Either<E, Cause<never>>
Cause.findDefect(cause); // Option<unknown>
Cause.findInterrupt(cause); // Option<unknown>
```

## Error in Effect.fn

When using `Effect.fn`, handle errors with combinators as additional arguments:

```ts
export const effectFunction = Effect.fn("effectFunction")(
  function* (n: number): Effect.fn.Return<string, SomeError> {
    yield* Effect.logInfo("Received number:", n);
    return yield* new SomeError({ message: "Failed to read the file" });
  },
  // Add error handling as additional arguments
  Effect.catch((error) => Effect.logError(`Error occurred: ${error}`)),
  Effect.annotateLogs({ method: "effectFunction" }),
);
```

## Common Patterns

### Validation with Multiple Errors

```ts
import { Effect, Schema } from "effect";

class ValidationError extends Schema.TaggedErrorClass<ValidationError>()(
  "ValidationError",
  { field: Schema.String, message: Schema.String },
) {}

const validateUser = Effect.fn("validateUser")(function* (user: {
  name: string;
  age: number;
}) {
  const errors: Array<ValidationError> = [];

  if (user.name.length < 2) {
    errors.push(
      new ValidationError({
        field: "name",
        message: "Name must be at least 2 characters",
      }),
    );
  }

  if (user.age < 18) {
    errors.push(
      new ValidationError({
        field: "age",
        message: "Must be at least 18 years old",
      }),
    );
  }

  if (errors.length > 0) {
    return yield* Effect.fail(errors[0]);
  }

  return user;
});
```

### Error Recovery Chain

```ts
const resilientFetch = (id: string) =>
  fetchUser(id).pipe(
    // Try primary source
    Effect.orElse(() => fetchFromCache(id)),
    // Retry on network errors
    Effect.retry({
      times: 3,
      schedule: Schedule.exponential("100 millis"),
    }),
    // Return null if all fail
    Effect.orElse(() => Effect.succeed(null)),
  );
```

## External Examples

See full examples:

- [Catch Tags](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/01_effect/03_errors/10_catch-tags.ts)
- [Reason Errors](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/01_effect/03_errors/20_reason-errors.ts)

## Best Practices

1. **Define errors with Schema.TaggedErrorClass** for type safety
2. **Use descriptive \_tag names** that clearly identify the error type
3. **Include context in error fields** (e.g., userId, operation name)
4. **Use catchTags for multiple error types** instead of nested catchTag calls
5. **Handle errors at appropriate layers** - don't let them bubble too far
6. **Use reasons for complex error hierarchies** (e.g., AI errors with rate limits, quotas)
7. **Always return when raising errors** in Effect.fn to ensure type safety

## Error Handling Decision Tree

Use this decision guide to choose the right error handling approach:

### Decision 1: Recovery vs Propagation

**"Do you want to RECOVER from this error and continue?"**

| If... | Use... | Example |
|-------|--------|---------|
| You want to retry | `Effect.retry` with `Schedule` | Network timeout → retry with exponential backoff |
| You want a fallback value | `orElse` or `catchTags` | Config missing → use defaults |
| You want to log and continue | `catch` with logging | Non-critical error → log warning |
| You want to transform error type | `mapError` | Convert to domain error |

**"Do you want to FAIL and PROPAGATE this error?"**

| If... | Use... | Example |
|-------|--------|---------|
| Validation failure | `yield* new ValidationError({...})` | Invalid input format |
| Business rule violation | `yield* new BusinessRuleError({...})` | Insufficient funds |
| Unrecoverable state | `return yield* new ErrorType({...})` | Database corruption |

### Decision 2: Which Combinator?

**For specific error types with different handlers:**

```ts
// Good — Use catchTags for multiple specific errors
Effect.catchTags({
  NotFoundError: () => fallbackValue,
  ValidationError: () => fallbackValue,
})
```

**For fallback after specific handling:**

```ts
// Good — Use catchTag then catch for final fallback
Effect.catchTag("NotFoundError", () => fallback)
Effect.catch(() => anotherFallback)
```

**For retryable errors:**

```ts
// Good — Use retry with schedule
Effect.retry({
  times: 3,
  schedule: Schedule.exponential("100 millis"),
})
```

### Anti-Patterns

**// Bad** — DON'T use catchTags when you should propagate:

```ts
// Wrong - catching and re-throwing defeats the purpose
Effect.catchTags({
  ValidationError: (e) => Effect.fail(e),  // Just re-raise it!
})
```

**// Good** — CORRECT: propagate validation errors with `return yield*`:

```ts
const validateInput = Effect.fn("validateInput")(function* (input) {
  if (!isValid(input)) {
    return yield* new ValidationError({ message: "Invalid" }); // Propagate
  }
  return process(input);
});
```

**// Good** — CORRECT: recover with fallback:

```ts
const withFallback = validateInput(input).pipe(
  Effect.catchTag("ValidationError", () => Effect.succeed(defaultValue)), // Recover
);
```

### Quick Reference

| Scenario | Pattern |
|----------|---------|
| Retry transient failure | `Effect.retry(Schedule.exponential(...))` |
| Use fallback value | `Effect.orElse(() => fallback)` |
| Handle multiple errors differently | `Effect.catchTags({...})` |
| Convert error type | `Effect.mapError(...)` |
| Fail with domain error | `return yield* new DomainError({...})` |
| Log and re-throw | `Effect.catch(...)` then re-raise |

---

## Quick Reference

```ts
// Define error
class MyError extends Schema.TaggedErrorClass<MyError>()("MyError", {
  field: Schema.String,
}) {}

// Catch specific
Effect.catchTag("MyError", (error) => handler);

// Catch multiple
Effect.catchTags({
  Error1: (e) => handler1,
  Error2: (e) => handler2,
});

// Catch all
Effect.catch((error) => handler);

// Retry
Effect.retry({ times: 3, schedule: Schedule.exponential("100 millis") });

// Timeout
Effect.timeout("5 seconds");
// Fallback
Effect.orElse(() => fallback);
```
