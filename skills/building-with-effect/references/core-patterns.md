# Core Effect Patterns

Essential patterns for Effect development.

See full example: [Creating Effects](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/01_effect/01_basics/10_creating-effects.ts)

> **See also**: [schema-classes.md](schema-classes.md) for Schema.Opaque, Schema.Class, and Schema.TaggedErrorClass definitions.

## Contents

- [Effect.fn (Recommended)](#effectfn-recommended) - Primary way to write functions that return Effects
- [Effect Creation](#effect-creation) - Creating effects from various sources
- [Generator Pattern](#generator-pattern) - Sequential composition with Effect.gen
- [Pipe Composition](#pipe-composition) - Chaining transformations
- [Combining Effects](#combining-effects) - Running multiple effects together
- [Conditional Execution](#conditional-execution) - Control flow patterns
- [Resource Safety](#resource-safety) - Managing resources with acquireRelease
- [Error Handling](#error-handling) - Catching and recovering from errors
- [Running Effects](#running-effects) - Executing effects with runtimes
- [Dual APIs](#dual-apis) - Data-first and data-last styles
- [Performance Tips](#performance-tips) - Optimization recommendations

## Effect.fn (Recommended)

The primary way to write functions that return Effects. `Effect.fn` provides:

- Automatic tracing spans
- Composable behavior via additional arguments
- Better stack traces

**Basic Usage**

```ts
import { Effect, Schema } from "effect";

class FileProcessingError extends Schema.TaggedErrorClass<FileProcessingError>()(
  "FileProcessingError",
  { message: Schema.String },
) {}

export const processFile = Effect.fn("processFile")(
  function* (path: string) {
    yield* Effect.log("Starting file processing...");

    // Always return when raising an error
    return yield* new FileProcessingError({ message: "Failed to process" });
  },
  // Add combinators as additional arguments (no .pipe needed)
  Effect.catch((error) => Effect.logError(`Error: ${error}`)),
  Effect.withSpan("processFile", { attributes: { method: "Effect.fn" } }),
);
```

**With Return Type Annotation**

```ts
import { Effect, Schema } from "effect";

class SomeError extends Schema.TaggedErrorClass<SomeError>()("SomeError", {
  message: Schema.String,
}) {}

export const effectFunction = Effect.fn("effectFunction")(
  function* (n: number): Effect.fn.Return<string, SomeError> {
    yield* Effect.logInfo("Received number:", n);
    return yield* new SomeError({ message: "Failed" });
  },
  Effect.catch((error) => Effect.logError(`Error: ${error}`)),
  Effect.annotateLogs({ method: "effectFunction" }),
);
```

## Effect Creation

**Success values**

```ts
Effect.succeed(value); // Immediate success
Effect.sync(() => compute()); // Lazy evaluation
Effect.promise(() => fetch()); // From Promise
```

**Failures**

```ts
Effect.fail(error); // Expected error
Effect.die(defect); // Unexpected error (defect)
Effect.failCause(cause); // Full cause chain
```

**From common sources**

```ts
import { Effect, Schema } from "effect";

class InvalidPayload extends Schema.TaggedErrorClass<InvalidPayload>()(
  "InvalidPayload",
  { input: Schema.String, cause: Schema.Defect },
) {}

// From sync code that may throw
export const parsePayload = Effect.fn("parsePayload")((input: string) =>
  Effect.try({
    try: () => JSON.parse(input),
    catch: (cause) => new InvalidPayload({ input, cause }),
  }),
);

// From Promise-based APIs
class UserLookupError extends Schema.TaggedErrorClass<UserLookupError>()(
  "UserLookupError",
  { userId: Schema.Number, cause: Schema.Defect },
) {}

export const fetchUser = Effect.fn("fetchUser")((userId: number) =>
  Effect.tryPromise({
    async try() {
      const user = await fetchUserFromApi(userId);
      return user;
    },
    catch: (cause) => new UserLookupError({ userId, cause }),
  }),
);

// From nullable values
const fromNullish = Effect.fromNullishOr(maybeValue).pipe(
  Effect.mapError(() => new MissingValueError()),
);

// From callback-style APIs
export const fromCallback = Effect.callback<number>((resume) => {
  const timeoutId = setTimeout(() => {
    resume(Effect.succeed(200));
  }, 10);

  // Return finalizer for interruption
  return Effect.sync(() => clearTimeout(timeoutId));
});
```

## Generator Pattern

**Sequential composition**

```ts
const program = Effect.gen(function* () {
  const user = yield* fetchUser(id);
  const posts = yield* fetchPosts(user.id);
  const comments = yield* fetchComments(posts[0].id);
  return { user, posts, comments };
});
```

**Early returns**

```ts
Effect.gen(function* () {
  const value = yield* compute();
  if (value < 0) return yield* Effect.fail(new NegativeError());
  return value * 2;
});
```

**Error handling in generator**

```ts
Effect.gen(function* () {
  const result = yield* riskyOperation().pipe(
    Effect.catchTag("NotFound", () => Effect.succeed(null)),
  );
  return result;
});
```

## Pipe Composition

**Chaining transformations**

```ts
const result = Effect.succeed(10).pipe(
  Effect.map((x) => x * 2),
  Effect.flatMap((x) => Effect.succeed(x + 5)),
  Effect.tap((x) => Effect.log(`Value: ${x}`)),
);
```

**Error channel operations**

```ts
effect.pipe(
  Effect.mapError((e) => new CustomError(e)),
  Effect.catchTag("NotFound", () => Effect.succeed(defaultValue)),
  Effect.retry({ times: 3 }),
);
```

## Combining Effects

**All (parallel by default)**

```ts
// Array
const results = yield * Effect.all([effect1, effect2, effect3]);

// Struct
const data =
  yield *
  Effect.all({
    user: fetchUser(id),
    posts: fetchPosts(id),
    settings: fetchSettings(id),
  });

// Sequential
Effect.all([e1, e2, e3], { concurrency: 1 });
```

**ForEach**

```ts
// Parallel
const results =
  yield *
  Effect.forEach([1, 2, 3], (n) => processItem(n), {
    concurrency: "unbounded",
  });

// Sequential
Effect.forEach(items, process, { concurrency: 1 });

// Batched
Effect.forEach(items, process, { concurrency: 5 });
```

## Conditional Execution

**if/else chains**

```ts
const program = Effect.gen(function* () {
  const value = yield* getValue();

  if (value > 100) {
    return yield* handleLarge(value);
  } else if (value > 50) {
    return yield* handleMedium(value);
  } else {
    return yield* handleSmall(value);
  }
});
```

**when/unless**

```ts
const maybeLog = Effect.when(shouldLog, () => Effect.log("Logging enabled"));

const skipIfZero = Effect.unless(value === 0, () => process(value));
```

## Resource Safety

**Basic pattern**

```ts
Effect.acquireRelease(
  acquire, // Effect that gets resource
  release, // Cleanup (runs even if interrupted)
);
```

**With usage**

```ts
Effect.acquireUseRelease(
  openConnection(),
  (conn) => query(conn),
  (conn) => closeConnection(conn),
);
```

**Scoped resources**

```ts
const scoped = Effect.acquireRelease(openFile("data.txt"), (file) =>
  closeFile(file),
);

const program = Effect.scoped(
  Effect.gen(function* () {
    const file = yield* scoped;
    return yield* readFile(file);
  }),
);
```

## Error Handling

**catchTag for specific errors**

```ts
import { Effect, Schema } from "effect";

class ParseError extends Schema.TaggedErrorClass<ParseError>()("ParseError", {
  input: Schema.String,
  message: Schema.String,
}) {}

class ReservedPortError extends Schema.TaggedErrorClass<ReservedPortError>()(
  "ReservedPortError",
  { port: Schema.Number },
) {}

declare const loadPort: (
  input: string,
) => Effect.Effect<number, ParseError | ReservedPortError>;

export const recovered = loadPort("80").pipe(
  // Catch multiple errors
  Effect.catchTag(["ParseError", "ReservedPortError"], () =>
    Effect.succeed(3000),
  ),
);

export const withFinalFallback = loadPort("invalid").pipe(
  Effect.catchTag("ReservedPortError", () => Effect.succeed(3000)),
  Effect.catch(() => Effect.succeed(3000)),
);
```

**catchTags for multiple handlers**

```ts
import { Effect, Schema } from "effect";

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
      Effect.succeed(`Network failed: ${error.statusCode}`),
  }),
);
```

**catchReason for errors with reasons**

```ts
import { Effect, Schema } from "effect";

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

export const handleOneReason = callModel.pipe(
  Effect.catchReason(
    "AiError", // Parent error tag
    "RateLimitError", // Reason tag to catch
    (reason) => Effect.succeed(`Retry after ${reason.retryAfter}s`),
    (reason) => Effect.succeed(`Other reason: ${reason._tag}`),
  ),
);

export const handleMultipleReasons = callModel.pipe(
  Effect.catchReasons("AiError", {
    RateLimitError: (reason) =>
      Effect.succeed(`Retry after ${reason.retryAfter}s`),
    QuotaExceededError: (reason) =>
      Effect.succeed(`Quota exceeded at ${reason.limit}`),
  }),
);
```

## Running Effects

**With NodeRuntime**

```ts
import { NodeRuntime } from "@effect/platform-node";
import { Effect, Layer } from "effect";

const Worker = Layer.effectDiscard(
  Effect.gen(function* () {
    yield* Effect.logInfo("Starting worker...");
    yield* Effect.forkScoped(
      Effect.gen(function* () {
        while (true) {
          yield* Effect.logInfo("Working...");
          yield* Effect.sleep("1 second");
        }
      }),
    );
  }),
);

const program = Layer.launch(Worker);

// runMain installs SIGINT/SIGTERM handlers
NodeRuntime.runMain(program, {
  disableErrorReporting: true,
});
```

**Using Layer.launch**

```ts
import { NodeHttpServer, NodeRuntime } from "@effect/platform-node";
import { Effect, Layer } from "effect";
import { HttpRouter, HttpServerResponse } from "effect/unstable/http";
import { createServer } from "node:http";

const HealthRoutes = HttpRouter.use(
  Effect.fn(function* (router) {
    yield* router.add(
      "GET",
      "/health",
      Effect.succeed(HttpServerResponse.text("ok")),
    );
  }),
);

const HttpServerLive = HttpRouter.serve(HealthRoutes).pipe(
  Layer.provide(NodeHttpServer.layer(createServer, { port: 3000 })),
);

// Layer.launch converts layer to long-running Effect
const main = Layer.launch(HttpServerLive);
NodeRuntime.runMain(main);
```

## Dual APIs

Many Effect functions support both data-first and data-last:

```ts
// Data-last (pipe-friendly)
effect.pipe(Effect.map(fn));

// Data-first
Effect.map(effect, fn);

// Both work identically
```

## Performance Tips

- Use `Effect.cached` for expensive reusable computations
- Prefer `Effect.suspend` over `Effect.sync` for heavy lazy work
- Use `Effect.withConcurrency` to limit parallel operations
- Batch operations with `Effect.forEach(..., { batching: true })`
- Consider `Micro` module for bundle-size sensitive apps
