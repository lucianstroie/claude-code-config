---
name: building-with-effect
description: Build TypeScript programs with the Effect library - type-safe error handling, dependency injection, concurrency, resource management, and composable abstractions. Use when working with Effect, Schema, or any @effect/* ecosystem package.
---

# Building with Effect

Effect is a powerful TypeScript library for building complex, type-safe programs with composable abstractions for error handling, dependency injection, concurrency, and resource management.

## Quick Start

**Using Effect.fn (Recommended)**

```ts
import { Effect, Schema } from "effect";

// Define errors with Schema.TaggedErrorClass
class FetchError extends Schema.TaggedErrorClass<FetchError>()("FetchError", {
  message: Schema.String,
}) {}

// Create functions with Effect.fn
export const fetchUser = Effect.fn("fetchUser")(
  function* (id: number) {
    yield* Effect.logInfo("Fetching user:", id);

    // Always return when raising an error
    return yield* new FetchError({ message: "Failed to fetch" });
  },
  // Add combinators as additional arguments (no .pipe needed)
  Effect.catch((error) => Effect.logError(`Error: ${error}`)),
  Effect.withSpan("fetchUser", { attributes: { method: "Effect.fn" } }),
);
```

**Generator Style**

```ts
const program = Effect.gen(function* () {
  const a = yield* Effect.succeed(10);
  const b = yield* Effect.succeed(20);
  return a + b;
});
```

**Running Effects**

```ts
// As Promise
Effect.runPromise(program).then(console.log);

// With NodeRuntime (recommended for apps)
import { NodeRuntime } from "@effect/platform-node";
NodeRuntime.runMain(program);

// Using Layer.launch as entry point
Layer.launch(WorkerLayer).pipe(NodeRuntime.runMain);
```

## Degrees of Freedom

Match the level of specificity to the task's fragility:

**Low Freedom** (specific patterns, consistency critical)

These operations have a narrow safe path - follow exactly:

- **Error definition**: Always use `Schema.TaggedErrorClass` with descriptive `_tag`
- **Service structure**: Extend `Context.Service` with static `layer` property
- **Effect.fn usage**: Always use `Effect.fn("name")` for functions returning Effects
- **Resource cleanup**: Always use `acquireUseRelease` or `Effect.addFinalizer`
- **Resource pattern selection**: Use `acquireUseRelease` for external resources, `Ref` for shared mutable state, `addFinalizer` for cleanup within existing scope
- **Error recovery vs propagation**: Use `catchTags`/`orElse` to recover; use `return yield* new Error()` to propagate (ALWAYS use `return yield*` to signal the function stops)

**Medium Freedom** (preferred patterns, some variation acceptable)

These have recommended approaches but context matters:

- **Combinator selection**: Choose based on need - `catchTag` for specific errors, `catchTags` for multiple, `catch` for all
- **Layer composition**: Use `Layer.provide` for dependency injection, order matters for overrides
- **Concurrency control**: Use `Effect.all` or `Effect.forEach` with appropriate `concurrency` option
- **Error recovery**: Select retry schedules based on failure characteristics

**High Freedom** (multiple valid approaches, context-dependent)

These depend on application needs:

- **Application architecture**: Service boundaries, layer organization, entry point structure
- **Testing strategies**: Test at service level, effect level, or integration level based on needs
- **Performance optimization**: Caching strategies, batching decisions, bundle size tradeoffs
- **Observability setup**: Logging granularity, tracing scope, metric selection

## Core Type

```ts
Effect<Success, Error, Requirements>;
```

- **Success**: Value type on success
- **Error**: Type-tracked errors
- **Requirements**: Services needed (use `never` if none)

## Key Operators

**Transformation**

- `map` - Transform success value
- `flatMap` / `andThen` - Chain effects
- `tap` - Side effects without changing value
- `mapError` - Transform error type

**Error Handling**

- `catch` - Handle all errors (renamed from `catchAll` in earlier versions)
- `catchTag` - Handle specific error types
- `catchTags` - Handle multiple tagged errors at once
- `catchReason` / `catchReasons` - Handle errors with reasons
- `catchFilter` - Handle filtered errors (renamed from `catchSome` in earlier versions)
- `orElse` - Fallback effect
- `retry` - Retry with policy

**Composition**

- `all` - Run multiple effects
- `forEach` - Map over collection
- `zip` / `zipWith` - Combine effects
- `provide` - Supply dependencies

## Best Practices

1. **Use Effect.fn** for functions that return Effects (not Effect.gen alone)
2. **Define errors with Schema.TaggedErrorClass** for type safety
3. **Use Context.Service** for dependency injection
4. **Build layers explicitly** with `Layer.effect` and compose with `Layer.provide`
5. **Use ExecutionPlan** for AI provider fallback strategies
6. **Handle interruptions** with `acquireRelease` for resources
7. **Use Layer.launch** as application entry point for long-running apps
8. **Enable dual APIs** when appropriate (data-first + data-last)
9. **Choose resource patterns deliberately**: See [Resource Pattern Selector](references/resource-management.md#resource-pattern-selector)
10. **Use error recovery for resilience**: See [Error Handling Decision Tree](references/error-handling.md#error-handling-decision-tree)
11. **Prefer Effect.forEach with concurrency**: See [Concurrency Anti-Patterns](references/concurrency.md#anti-patterns-to-avoid)

## Workflows

Use these checklists for complex multi-step tasks:

### Creating a New Service

Copy this checklist and track progress:

```
Service Creation Progress:
- [ ] Step 1: Define error types with Schema.TaggedErrorClass
- [ ] Step 2: Create service class extending Context.Service
- [ ] Step 3: Implement methods using Effect.fn
- [ ] Step 4: Build Layer.effect with service implementation
- [ ] Step 5: Provide dependencies via Layer.provide
- [ ] Step 6: Test the service layer
```

**Step 1: Define error types**

```ts
class ServiceError extends Schema.TaggedErrorClass<ServiceError>()(
  "ServiceError",
  { cause: Schema.Defect },
) {}
```

**Step 2: Create service class**

```ts
export class MyService extends Context.Service<
  MyService,
  {
    method(): Effect.Effect<ReturnType, ServiceError>;
  }
>()("namespace/MyService") {}
```

**Step 3: Implement methods**

```ts
const method = Effect.fn("MyService.method")(function* () {
  // Implementation
});
```

**Step 4-6: Build and test layer**

See [Services & Layers](references/services-layers.md) for complete examples.

### Setting Up AI Integration

Copy this checklist and track progress:

```
AI Setup Progress:
- [ ] Step 1: Install provider packages (@effect/ai-openai, @effect/ai-anthropic)
- [ ] Step 2: Configure client layers with API keys
- [ ] Step 3: Define ExecutionPlan for fallback strategy
- [ ] Step 4: Create AI service with Effect.fn
- [ ] Step 5: Implement error handling with mapError
- [ ] Step 6: Provide client layers to service layer
```

See [AI Modules](references/ai-modules.md) for detailed implementation.

### Error Handling Strategy

Copy this checklist and track progress:

```
Error Handling Progress:
- [ ] Step 1: Define all error types with Schema.TaggedErrorClass
- [ ] Step 2: Use catchTags for multiple specific error handlers
- [ ] Step 3: Add catch for final fallback if needed
- [ ] Step 4: Consider retry with Schedule for transient failures
- [ ] Step 5: Log errors at appropriate layers
- [ ] Step 6: Test error scenarios
```

See [Error Handling](references/error-handling.md) for patterns and examples.

## Common Patterns

### Service with Effect.fn

```ts
import { Effect, Context, Layer, Schema } from "effect";

class DatabaseError extends Schema.TaggedErrorClass<DatabaseError>()(
  "DatabaseError",
  { cause: Schema.Defect },
) {}

export class Database extends Context.Service<
  Database,
  {
    query(sql: string): Effect.Effect<unknown[], DatabaseError>;
  }
>()("app/Database") {
  static readonly layer = Layer.effect(
    Database,
    Effect.gen(function* () {
      const query = Effect.fn("Database.query")(function* (sql: string) {
        yield* Effect.log("Executing SQL:", sql);
        return [{ id: 1, name: "Alice" }];
      });
      return Database.of({ query });
    }),
  );
}

// Exported type with proper inference
export type DatabaseService = Database["Service"];
```

### Error Handling with catchTags

```ts
const configWithFallback = loadConfig().pipe(
  Effect.catchTags({
    ParseError: () => Effect.succeed(defaultConfig),
    FileError: () => Effect.succeed(defaultConfig),
  }),
);
```

### Resource Safety

```ts
const program = Effect.acquireUseRelease(
  openFile("data.txt"),
  (file) => processFile(file),
  (file) => closeFile(file),
);
```

## Package Structure

**Core Package**

```ts
import { Effect } from "effect";
```

**Unstable Modules** (may have breaking changes in minor releases)

```ts
import { Schema } from "effect/unstable/schema";
import { HttpClient } from "effect/unstable/http";
import { LanguageModel } from "effect/unstable/ai";
import { PubSub } from "effect/unstable/pubsub";
```

**Platform-Specific Packages** (separate packages)

```ts
import { NodeRuntime } from "@effect/platform-node";
import { SqlClient } from "@effect/sql-pg";
import { OpenAiClient } from "@effect/ai-openai";
```

## References

Dive deeper into specific topics and patterns:

- **[Core Patterns](references/core-patterns.md)** - Foundational Effect patterns with Effect.fn
- **[Error Handling](references/error-handling.md)** - Schema.TaggedErrorClass, catchTags, catchReason
- **[Services & Layers](references/services-layers.md)** - Dependency injection with Context
- **[Concurrency](references/concurrency.md)** - Fibers, racing, interruption, coordination
- **[Data Types](references/data-types.md)** - Option, Either, Chunk, HashSet, Stream
- **[Streams](references/streams.md)** - Creating and consuming streams
- **[PubSub](references/pubsub.md)** - Event broadcasting and subscription
- **[Schedules](references/schedules.md)** - Retry, repeat, and scheduling patterns
- **[AI Modules](references/ai-modules.md)** - LLM integration with tools and chat
- **[HTTP Client/Server](references/http-client-server.md)** - HttpClient and HttpApi
- **[Resource Management](references/resource-management.md)** - Scope, acquire/release patterns
- **[Schema](references/schema.md)** - Quick start & index
- **[Observability](references/observability.md)** - Logging, metrics, tracing with Otlp
- **[Testing](references/testing.md)** - @effect/vitest patterns
- **[Integration](references/integration.md)** - ManagedRuntime for non-Effect code
- **[Batching](references/batching.md)** - RequestResolver for batching
- **[Child Process](references/child-process.md)** - Process management
- **[CLI](references/cli.md)** - CLI application building
- **[Cluster](references/cluster.md)** - Distributed entities
- **[Migration Guide](references/migration.md)** - Migrating from Effect v3 to v4

## Anti-Patterns to Avoid

- Using try/catch with Effect (defeats type safety)
- Mixing Promise-based and Effect-based code without conversion
- Not handling all error cases (use catch or match)
- Ignoring resource cleanup (always use acquireRelease)
- Running effects at module level (breaks composability)
- Using global state instead of Services
- Overusing Effect for simple synchronous operations
- Using Effect.gen alone instead of Effect.fn for functions

## Troubleshooting

**Type errors with Requirements**

- Ensure all services are provided via `Effect.provide`
- Check Layer composition matches service dependencies
- Use `Effect.provideService` for quick inline provisions

**Effects not executing**

- Effects are lazy - must be run with `runPromise`, `runSync`, or `runFork`
- Check that effect is actually yielded in generator context

**Performance issues**

- Avoid excessive allocations in hot loops
- Use `Effect.cached` for expensive computations
- Consider `Micro` module for bundle-size sensitive apps

## Example Files

Browse detailed examples in the [effect-smol/ai-docs/src/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/) directory:

- **[Effect Basics](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/01_effect/01_basics/)** - Creating effects, pipe composition
- **[Services](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/01_effect/02_services/)** - Context.Service, Layer composition
- **[Error Handling](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/01_effect/03_errors/)** - catchTags, catchReason, error hierarchies
- **[Resources](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/01_effect/04_resources/)** - acquireRelease, Scope
- **[PubSub](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/01_effect/06_pubsub/)** - Event broadcasting
- **[Streams](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/02_stream/)** - Creating, consuming, encoding
- **[Integration](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/03_integration/)** - ManagedRuntime for non-Effect code
- **[Batching](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/05_batching/)** - RequestResolver patterns
- **[Schedules](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/06_schedule/)** - Retry and repeat strategies
- **[Observability](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/08_observability/)** - Logging, tracing, metrics
- **[Testing](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/09_testing/)** - @effect/vitest patterns
- **[HTTP](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/50_http-client/)** - HttpClient and HttpApi
- **[Child Process](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/60_child-process/)** - Process management
- **[CLI](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/70_cli/)** - CLI application building
- **[AI](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/71_ai/)** - Language models, tools, chat
- **[Cluster](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/80_cluster/)** - Distributed entities
