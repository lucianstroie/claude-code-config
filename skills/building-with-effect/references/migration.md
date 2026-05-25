# Migrating from Effect v3 to v4

This guide helps you migrate your Effect applications from v3 to v4.

See related examples in [effect-smol/ai-docs/src/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/)

## Overview

Effect v4 is a major release with structural and organizational changes. The core programming model — `Effect`, `Layer`, `Schema`, `Stream`, etc. — remains the same, but how packages are organized, versioned, and imported has changed significantly.

### Key Changes

1. **Effect.fn** - New recommended way to write functions that return Effects
2. **Schema.TaggedErrorClass** - Type-safe error definitions with Schema
3. **Unified versioning** - All ecosystem packages share a single version number
4. **Package consolidation** - Platform, RPC, Cluster, and more merged into core `effect`
5. **Context** - New dependency injection system replacing Context
6. **Yieldable trait** - More explicit type safety for yieldable types
7. **Automatic fiber keep-alive** - No need for `runMain` in most cases
8. **Layer memoization** - Automatic across `Effect.provide` calls
9. **Unstable modules** - New features under `effect/unstable/*` paths

## Effect.fn Migration (New in v4)

Effect v4 introduces `Effect.fn` as the recommended way to write functions that return Effects.

### Writing Functions

**v3 (not recommended):**

```ts
import { Effect } from "effect";

// Function returning Effect.gen
const fetchUser = (id: string) =>
  Effect.gen(function* () {
    yield* Effect.log("Fetching user:", id);
    const user = yield* database.query(
      `SELECT * FROM users WHERE id = '${id}'`,
    );
    return user;
  });
```

**v4 (recommended):**

```ts
import { Effect, Schema } from "effect";

class FetchError extends Schema.TaggedErrorClass<FetchError>()("FetchError", {
  message: Schema.String,
}) {}

export const fetchUser = Effect.fn("fetchUser")(
  function* (id: string) {
    yield* Effect.logInfo("Fetching user:", id);

    // Always return when raising an error
    return yield* new FetchError({ message: "Failed to fetch user" });
  },
  // Add combinators as additional arguments (no .pipe needed)
  Effect.catch((error) => Effect.logError(`Error: ${error}`)),
  Effect.withSpan("fetchUser", { attributes: { method: "Effect.fn" } }),
);
```

### Benefits of Effect.fn

- **Automatic tracing spans** - Each call gets a span with the function name
- **Composable behavior** - Add combinators as additional arguments
- **Better stack traces** - Name appears in error traces
- **Type-safe returns** - Use `Effect.fn.Return<Success, Error>` for return types

## Schema.TaggedErrorClass Migration (New in v4)

Effect v4 recommends using `Schema.TaggedErrorClass` instead of `Data.TaggedError` for error definitions.

### Defining Errors

**v3:**

```ts
import { Data } from "effect";

class NetworkError extends Data.TaggedError("NetworkError")<{
  statusCode: number;
  message: string;
}> {}

class ValidationError extends Data.TaggedError("ValidationError")<{
  field: string;
  message: string;
}> {}
```

**v4:**

```ts
import { Schema } from "effect";

class NetworkError extends Schema.TaggedErrorClass<NetworkError>()(
  "NetworkError",
  {
    statusCode: Schema.Number,
    message: Schema.String,
  },
) {}

class ValidationError extends Schema.TaggedErrorClass<ValidationError>()(
  "ValidationError",
  {
    field: Schema.String,
    message: Schema.String,
  },
) {}

// Error with union of reasons (for complex error hierarchies)
class RateLimitError extends Schema.TaggedErrorClass<RateLimitError>()(
  "RateLimitError",
  { retryAfter: Schema.Number },
) {}

class QuotaExceededError extends Schema.TaggedErrorClass<QuotaExceededError>()(
  "QuotaExceededError",
  { limit: Schema.Number },
) {}

class AiError extends Schema.TaggedErrorClass<AiError>()("AiError", {
  reason: Schema.Union(RateLimitError, QuotaExceededError),
}) {}
```

### Benefits of Schema.TaggedErrorClass

- **Schema validation** - Error properties are validated
- **Better serialization** - Errors can be encoded/decoded
- **Type inference** - Better TypeScript inference for error types
- **Reason hierarchies** - Support for nested error reasons with `catchReason`

## Package Changes

### Unified Versioning

In v3, packages were versioned independently:

```json
{
  "effect": "^3.0.0",
  "@effect/platform": "^0.50.0",
  "@effect/sql": "^0.40.0"
}
```

In v4, all packages share the same version:

```json
{
  "effect": "^4.0.0",
  "@effect/platform-node": "^4.0.0",
  "@effect/sql-pg": "^4.0.0"
}
```

### Package Consolidation

Many packages have been merged into the core `effect` package:

| v3 Package         | v4 Location               |
| ------------------ | ------------------------- |
| `@effect/platform` | `effect` (core)           |
| `@effect/rpc`      | `effect/unstable/rpc`     |
| `@effect/cluster`  | `effect/unstable/cluster` |
| `@effect/schema`   | `effect/unstable/schema`  |
| `@effect/cli`      | `effect/unstable/cli`     |
| `@effect/http`     | `effect/unstable/http`    |

### Unstable Modules

v4 introduces **unstable modules** under `effect/unstable/*` paths. These may receive breaking changes in minor releases:

```ts
// Unstable - may change in minor releases
import { Schema } from "effect/unstable/schema";
import { HttpClient } from "effect/unstable/http";

// Stable
import { Effect } from "effect";
```

## Services Migration

### Context.Tag → Context.Service

**v3:**

```ts
import { Context, Effect } from "effect";

interface Database {
  readonly query: (sql: string) => Effect.Effect<unknown[]>;
}

class Database extends Context.Tag("Database")<Database, Database>() {}
```

**v4:**

```ts
import { Context, Effect } from "effect";

interface Database {
  readonly query: (sql: string) => Effect.Effect<unknown[]>;
}

// Function syntax
const Database = Context.Service<Database>("Database");

// Or class syntax
class Database extends Context.Service<Database>()("Database", {
  query: (sql: string) => Effect.Effect<unknown[]>,
})() {}
```

### Effect.Service → Context.Service

**v3:**

```ts
import { Effect, Layer } from "effect";

class Logger extends Effect.Service<Logger>()("Logger", {
  effect: Effect.gen(function* () {
    const config = yield* Config;
    return { log: (msg: string) => Effect.log(msg) };
  }),
  dependencies: [Config.Default],
}) {}

// Logger.Default auto-generated
const program = Effect.provide(Logger.Default);
```

**v4:**

```ts
import { Effect, Layer, Context } from "effect";

class Logger extends Context.Service<Logger>()("Logger", {
  make: Effect.gen(function* () {
    const config = yield* Config;
    return { log: (msg: string) => Effect.log(msg) };
  }),
}) {
  // Build layer explicitly
  static readonly layer = Layer.effect(this, this.make).pipe(
    Layer.provide(Config.layer),
  );
}

// Use explicit layer
const program = Effect.provide(Logger.layer);
```

### Effect.Tag → Context.Service

**v3:**

```ts
import { Effect } from "effect";

class Notifications extends Effect.Tag("Notifications")<
  Notifications,
  { readonly notify: (message: string) => Effect.Effect<void> }
>() {}

// Static accessor proxy
const program = Notifications.notify("hello");
```

**v4:**

```ts
import { Effect, Context } from "effect";

class Notifications extends Context.Service<Notifications>()(
  "Notifications",
  { notify: (message: string) => Effect.Effect<void> },
)() {}

// Use yield* in generators (recommended)
const program = Effect.gen(function* () {
  const n = yield* Notifications;
  yield* n.notify("hello");
});

// Or Service.use for one-liners
const program2 = Notifications.use((n) => n.notify("hello"));
```

### Context.Reference → Context.Reference

**v3:**

```ts
import { Context } from "effect";

class LogLevel extends Context.Reference<LogLevel>()("LogLevel", {
  defaultValue: () => "info" as const,
}) {}
```

**v4:**

```ts
import { Context } from "effect";

const LogLevel = Context.Reference<"info" | "warn" | "error">("LogLevel", {
  defaultValue: () => "info" as const,
});
```

## Error Handling Migration

### Renamed Combinators

| v3                       | v4                        |
| ------------------------ | ------------------------- |
| `Effect.catchAll`        | `Effect.catch`            |
| `Effect.catchAllCause`   | `Effect.catchCause`       |
| `Effect.catchAllDefect`  | `Effect.catchDefect`      |
| `Effect.catchSome`       | `Effect.catchFilter`      |
| `Effect.catchSomeCause`  | `Effect.catchCauseFilter` |
| `Effect.catchSomeDefect` | Removed                   |

**v3:**

```ts
effect.pipe(
  Effect.catchAll((error) => Effect.succeed(`recovered: ${error}`)),
  Effect.catchAllCause((cause) => Effect.succeed("recovered from cause")),
  Effect.catchSome((error) =>
    error._tag === "Retryable"
      ? Option.some(Effect.succeed("caught"))
      : Option.none(),
  ),
);
```

**v4:**

```ts
import { Effect, Filter } from "effect";

effect.pipe(
  Effect.catch((error) => Effect.succeed(`recovered: ${error}`)),
  Effect.catchCause((cause) => Effect.succeed("recovered from cause")),
  Effect.catchFilter(
    Filter.fromPredicate((error: MyError) => error._tag === "Retryable"),
    (error) => Effect.succeed("caught"),
  ),
);
```

### New in v4

```ts
// Catch specific reason within tagged error
Effect.catchReason("AiError", "RateLimitError", (reason) =>
  Effect.succeed("rate limited"),
);

// Catch multiple reasons
Effect.catchReasons("AiError", {
  RateLimitError: () => Effect.succeed("rate limited"),
  QuotaExceededError: () => Effect.succeed("quota exceeded"),
});

// Eager catch (optimization)
Effect.catchEager((error) => Effect.succeed("recovered"));
```

## Concurrency Migration

### Forking Changes

| v3                            | v4                                             |
| ----------------------------- | ---------------------------------------------- |
| `Effect.fork`                 | `Effect.forkChild`                             |
| `Effect.forkDaemon`           | `Effect.forkDetach`                            |
| `Effect.forkAll`              | Removed - use `Effect.all` with `forkChild`    |
| `Effect.forkWithErrorHandler` | Removed - use `Fiber.join` with error handling |

**v3:**

```ts
const fiber = yield * Effect.fork(task);
const daemon = yield * Effect.forkDaemon(backgroundTask);
```

**v4:**

```ts
const fiber = yield * Effect.forkChild(task);
const daemon = yield * Effect.forkDetach(backgroundTask);

// With options
const fiber2 =
  yield *
  Effect.forkChild(task, {
    startImmediately: true,
    uninterruptible: true,
  });
```

### Non-Yieldable Types

In v4, `Ref`, `Deferred`, and `Fiber` are no longer Effect subtypes:

| v3 (yieldable)    | v4 (use explicit method)          |
| ----------------- | --------------------------------- |
| `yield* ref`      | `yield* Ref.get(ref)`             |
| `yield* deferred` | `yield* Deferred.await(deferred)` |
| `yield* fiber`    | `yield* Fiber.join(fiber)`        |

**v3:**

```ts
const ref = yield * Ref.make(0);
const value = yield * ref; // Ref was yieldable

const deferred = yield * Deferred.make<string>();
const value2 = yield * deferred; // Deferred was yieldable

const fiber = yield * Effect.fork(task);
const result = yield * fiber; // Fiber was yieldable
```

**v4:**

```ts
const ref = yield * Ref.make(0);
const value = yield * Ref.get(ref); // Use Ref.get

const deferred = yield * Deferred.make<string>();
const value2 = yield * Deferred.await(deferred); // Use Deferred.await

const fiber = yield * Effect.forkChild(task);
const result = yield * Fiber.join(fiber); // Use Fiber.join
```

## FiberRef Migration

In v4, `FiberRef` has been replaced by `Context.Reference`:

### Built-in References

| v3 FiberRef                         | v4 Reference                       |
| ----------------------------------- | ---------------------------------- |
| `FiberRef.currentConcurrency`       | `References.CurrentConcurrency`    |
| `FiberRef.currentLogLevel`          | `References.CurrentLogLevel`       |
| `FiberRef.currentMinimumLogLevel`   | `References.MinimumLogLevel`       |
| `FiberRef.currentLogAnnotations`    | `References.CurrentLogAnnotations` |
| `FiberRef.currentLogSpan`           | `References.CurrentLogSpans`       |
| `FiberRef.currentScheduler`         | `References.Scheduler`             |
| `FiberRef.currentMaxOpsBeforeYield` | `References.MaxOpsBeforeYield`     |
| `FiberRef.currentTracerEnabled`     | `References.TracerEnabled`         |
| `FiberRef.unhandledErrorLogLevel`   | `References.UnhandledLogLevel`     |

**v3:**

```ts
import { Effect, FiberRef, LogLevel } from "effect";

const program = Effect.gen(function* () {
  const level = yield* FiberRef.get(FiberRef.currentLogLevel);
  yield* FiberRef.set(FiberRef.currentLogLevel, LogLevel.Debug);
});

Effect.locally(program, FiberRef.currentLogLevel, LogLevel.Debug);
```

**v4:**

```ts
import { Effect, References } from "effect";

const program = Effect.gen(function* () {
  const level = yield* References.CurrentLogLevel;
  // References are services - use provideService for scoped changes
});

Effect.provideService(program, References.CurrentLogLevel, "Debug");
```

### Custom References

**v3:**

```ts
const requestId = yield * FiberRef.make("unknown");
yield * FiberRef.set(requestId, "req-123");
```

**v4:**

```ts
const RequestId = Context.Reference<string>("RequestId", {
  defaultValue: () => "unknown",
});

// Use like a service
const program = Effect.gen(function* () {
  const id = yield* RequestId;
});

// Override with provideService
Effect.provideService(program, RequestId, "req-123");
```

## Scope Migration

**v3:**

```ts
import { Effect, Scope } from "effect";

const program = Effect.gen(function* () {
  const scope = yield* Scope.make();
  yield* Scope.extend(myEffect, scope);
});
```

**v4:**

```ts
import { Effect, Scope } from "effect";

const program = Effect.gen(function* () {
  const scope = yield* Scope.make();
  yield* Scope.provide(scope)(myEffect);
  // Or: Scope.provide(myEffect, scope)
});
```

## Cause Migration

In v4, `Cause<E>` has been flattened:

### Structure Changes

**v3:**

```ts
// Recursive tree structure
Cause<E> = Empty | Fail<E> | Die | Interrupt | Sequential<E> | Parallel<E>;
```

**v4:**

```ts
// Flattened array
interface Cause<E> {
  readonly reasons: ReadonlyArray<Reason<E>>;
}
type Reason<E> = Fail<E> | Die | Interrupt;
```

### API Changes

| v3                                    | v4                                |
| ------------------------------------- | --------------------------------- |
| `Cause.Sequential` / `Cause.Parallel` | `Cause.combine`                   |
| `Cause.isFailType(cause)`             | `Cause.isFailReason(reason)`      |
| `Cause.isDieType(cause)`              | `Cause.isDieReason(reason)`       |
| `Cause.isInterruptType(cause)`        | `Cause.isInterruptReason(reason)` |
| `Cause.isFailure(cause)`              | `Cause.hasFails(cause)`           |
| `Cause.isDie(cause)`                  | `Cause.hasDies(cause)`            |
| `Cause.isInterrupted(cause)`          | `Cause.hasInterrupts(cause)`      |
| `Cause.isInterruptedOnly(cause)`      | `Cause.hasInterruptsOnly(cause)`  |
| `Cause.failureOption(cause)`          | `Cause.findErrorOption(cause)`    |
| `Cause.failureOrCause(cause)`         | `Cause.findError(cause)`          |
| `Cause.dieOption(cause)`              | `Cause.findDefect(cause)`         |
| `Cause.interruptOption(cause)`        | `Cause.findInterrupt(cause)`      |

### Error Classes

| v3                          | v4                      |
| --------------------------- | ----------------------- |
| `NoSuchElementException`    | `NoSuchElementError`    |
| `TimeoutException`          | `TimeoutError`          |
| `IllegalArgumentException`  | `IllegalArgumentError`  |
| `ExceededCapacityException` | `ExceededCapacityError` |
| `UnknownException`          | `UnknownError`          |

## Data Types Migration

### Either → Result

**v3:**

```ts
import { Either } from "effect";

Either.right(42);
Either.left("error");
Either.isRight(either);
Either.isLeft(either);
```

**v4:**

```ts
import { Result } from "effect";

Result.ok(42);
Result.err("error");
Result.isOk(result);
Result.isErr(result);
```

### Equality

**v3:**

```ts
import { Equal } from "effect";

Equal.equals({ a: 1 }, { a: 1 }); // false (reference equality)
Equal.equals(NaN, NaN); // false
Equal.equivalence<number>();
```

**v4:**

```ts
import { Equal } from "effect";

Equal.equals({ a: 1 }, { a: 1 }); // true (structural equality)
Equal.equals(NaN, NaN); // true
Equal.asEquivalence<number>(); // renamed

// Opt out of structural equality
const obj = Equal.byReference({ a: 1 });
Equal.equals(obj, { a: 1 }); // false
```

## Schema Migration

> **See also**: The [Schema Quick Start & Index](schema.md) provides a comprehensive topic index for all Schema documentation.
>
> For detailed API reference, see:
> - [schema-validation.md](schema-validation.md) - refinement→check changes
> - [schema-composite.md](schema-composite.md) - propertySignature changes  
> - [schema-transformations.md](schema-transformations.md) - transformation changes
> - [schema-classes.md](schema-classes.md) - brand/class changes

### Import Changes

**v3:**

```ts
import { Schema } from "@effect/schema";
```

**v4:**

```ts
import { Schema } from "effect/unstable/schema";
// or: import { Schema } from "effect/schema";
```

### Refinements → Checks

**v3:**

```ts
Schema.String.pipe(Schema.minLength(5));
Schema.Number.pipe(Schema.positive());
Schema.Number.pipe(Schema.int());
```

**v4:**

```ts
Schema.String.check(Schema.isMinLength(5));
Schema.Number.check(Schema.isPositive());
Schema.Number.check(Schema.isInt());
```

### Transformations

**v3:**

```ts
Schema.transform(Schema.String, Schema.Date, {
  decode: (s) => new Date(s),
  encode: (d) => d.toISOString(),
});
```

**v4:**

```ts
import { SchemaGetter } from "effect/unstable/schema";

Schema.Date.pipe(
  Schema.encodeTo(Schema.String, {
    decode: SchemaGetter.Date(),
    encode: SchemaGetter.String(),
  }),
);
```

### Struct Fields

**v3:**

```ts
Schema.Struct({
  id: Schema.Number,
  name: Schema.String,
  email: Schema.optional(Schema.String),
});
```

**v4:**

```ts
Schema.Struct({
  id: Schema.Number,
  name: Schema.String,
  // Exact optional (key can be absent)
  email: Schema.optionalKey(Schema.String),
  // Optional with undefined
  phone: Schema.optional(Schema.String),
});
```

## Runtime Changes

### Runtime<R> Removed

**v3:**

```ts
import { Runtime } from "effect";

const runtime: Runtime<MyServices> = /* ... */;
Runtime.runPromise(runtime, effect);
```

**v4:**

```ts
// Runtime<R> removed - use Context<R>
// Run functions live directly on Effect
Effect.runPromise(effect);
Effect.runSync(effect);
Effect.runFork(effect);
```

### Automatic Fiber Keep-Alive

**v3:**

```ts
import { NodeRuntime } from "@effect/platform-node";

// Required to keep process alive
NodeRuntime.runMain(program);
```

**v4:**

```ts
// Core runtime now handles keep-alive automatically
Effect.runPromise(program);

// runMain still recommended for signal handling and exit codes
import { NodeRuntime } from "@effect/platform-node";
NodeRuntime.runMain(program);
```

## Quick Reference Tables

### Service Patterns

| v3                                                     | v4                                                          |
| ------------------------------------------------------ | ----------------------------------------------------------- |
| `Context.GenericTag<T>(id)`                            | `Context.Service<T>(id)`                                 |
| `Context.Tag(id)<Self, Shape>()`                       | `Context.Service<Self, Shape>()(id)`                     |
| `Effect.Tag(id)<Self, Shape>()`                        | `Context.Service<Self, Shape>()(id)`                     |
| `Effect.Service<Self>()(id, { effect, dependencies })` | `Context.Service<Self>()(id, { make })` + explicit layer |
| `Context.Reference<Self>()(id, opts)`                  | `Context.Reference<T>(id, opts)`                         |
| `Service.Default`                                      | `Service.layer` (explicit)                                  |

### Error Handling

| v3                      | v4                        |
| ----------------------- | ------------------------- |
| `Effect.catchAll`       | `Effect.catch`            |
| `Effect.catchAllCause`  | `Effect.catchCause`       |
| `Effect.catchAllDefect` | `Effect.catchDefect`      |
| `Effect.catchSome`      | `Effect.catchFilter`      |
| `Effect.catchSomeCause` | `Effect.catchCauseFilter` |

### Concurrency

| v3                  | v4                                |
| ------------------- | --------------------------------- |
| `Effect.fork`       | `Effect.forkChild`                |
| `Effect.forkDaemon` | `Effect.forkDetach`               |
| `Effect.forkAll`    | Removed                           |
| `yield* ref`        | `yield* Ref.get(ref)`             |
| `yield* deferred`   | `yield* Deferred.await(deferred)` |
| `yield* fiber`      | `yield* Fiber.join(fiber)`        |

### Cause

| v3                                    | v4                             |
| ------------------------------------- | ------------------------------ |
| `Cause.Sequential` / `Cause.Parallel` | `Cause.combine`                |
| `Cause.isFailType(cause)`             | `Cause.isFailReason(reason)`   |
| `Cause.isFailure(cause)`              | `Cause.hasFails(cause)`        |
| `Cause.failureOption(cause)`          | `Cause.findErrorOption(cause)` |
| `*Exception` classes                  | `*Error` classes               |

### Data Types

| v3                                     | v4                                    |
| -------------------------------------- | ------------------------------------- |
| `Either`                               | `Result`                              |
| `Either.right`                         | `Result.ok`                           |
| `Either.left`                          | `Result.err`                          |
| `Equal.equals({a:1}, {a:1})` → `false` | `Equal.equals({a:1}, {a:1})` → `true` |
| `Equal.equivalence()`                  | `Equal.asEquivalence()`               |

### Other

| v3               | v4                       |
| ---------------- | ------------------------ |
| `Scope.extend`   | `Scope.provide`          |
| `FiberRef`       | `Context.Reference`   |
| `Runtime<R>`     | Removed                  |
| `@effect/schema` | `effect/unstable/schema` |

## Migration Checklist

- [ ] Update package versions to unified v4 versions
- [ ] Replace `Context.Tag` with `Context.Service`
- [ ] Replace `Effect.Service` with `Context.Service` + explicit layers
- [ ] Replace `Effect.Tag` with `Context.Service` (remove static accessors)
- [ ] Update error handling: `catchAll` → `catch`, etc.
- [ ] Update forking: `fork` → `forkChild`, `forkDaemon` → `forkDetach`
- [ ] Replace `yield* ref` with `yield* Ref.get(ref)`
- [ ] Replace `yield* deferred` with `yield* Deferred.await(deferred)`
- [ ] Replace `yield* fiber` with `yield* Fiber.join(fiber)`
- [ ] Replace `FiberRef` with `Context.Reference`
- [ ] Replace `Scope.extend` with `Scope.provide`
- [ ] Update Cause handling for flattened structure
- [ ] Replace `Either` with `Result`
- [ ] Update Schema imports and API
- [ ] Remove `Runtime<R>` usage
- [ ] Test thoroughly - especially service dependency graphs

## Getting Help

- **Official Docs**: https://effect.website
- **API Reference**: https://effect-ts.github.io/effect
- **Discord Community**: https://discord.gg/effect-ts
- **GitHub**: https://github.com/Effect-TS/effect
- **Migration Issues**: Check the [effect-smol](https://github.com/Effect-TS/effect-smol) repository for latest migration notes
