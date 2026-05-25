# Services & Layers

Dependency injection and context management with Context (v4).

## Overview

In Effect v4, the dependency injection system uses **Context** for dependency management. Services are defined using `Context.Service` and provided via Layers.

## Services

### Define Service with Effect.fn

**Recommended: Using Context.Service with class extension**

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
      // Define methods using Effect.fn
      const query = Effect.fn("Database.query")(function* (sql: string) {
        yield* Effect.log("Executing SQL query:", sql);
        return [
          { id: 1, name: "Alice" },
          { id: 2, name: "Bob" },
        ];
      });

      return Database.of({ query });
    }),
  );
}

// If you ever need to access the service type, use `Database["Service"]`
export type DatabaseService = Database["Service"]
```

**With dependencies**

```ts
import { Effect, Context, Layer, Schema } from "effect";

class UserRespositoryError extends Schema.TaggedErrorClass<UserRespositoryError>()(
  "UserRespositoryError",
  { reason: Schema.Defect },
) {}

export class UserRepository extends Context.Service<
  UserRepository,
  {
    findById(
      id: string,
    ): Effect.Effect<
      Option<{ readonly id: string; readonly name: string }>,
      UserRespositoryError
    >;
  }
>()("myapp/UserRepository") {
  // Layer without dependencies exposed
  static readonly layerNoDeps: Layer.Layer<UserRepository, never, Database> =
    Layer.effect(
      UserRepository,
      Effect.gen(function* () {
        const db = yield* Database;

        const findById = Effect.fn("UserRepository.findById")(
          function* (id: string) {
            const results = yield* db.query(
              `SELECT * FROM users WHERE id = '${id}'`,
            );
            return Array.head(results);
          },
          Effect.mapError((reason) => new UserRespositoryError({ reason })),
        );

        return UserRepository.of({ findById });
      }),
    );

  // Layer with Database dependency provided
  static readonly layer: Layer.Layer<UserRepository, never, Database> =
    this.layerNoDeps.pipe(Layer.provide(Database.layer));
}
```

### Use Service

**Yield in generators (recommended)**

```ts
const program = Effect.gen(function* () {
  const db = yield* Database;
  const results = yield* db.query("SELECT * FROM users");
  return results;
});
```

**Using Service.use (one-liner)**

```ts
import { Service } from "effect";

// Use for single operations
const program = Database.use((db) => db.query("SELECT * FROM users"));

// For synchronous access
const getConfig = Config.useSync((c) => c.port);
```

> **Note:** Prefer `yield*` over `use` in most cases. `yield*` makes dependencies visible in the effect type, while `use` hides them in the callback.

## Layers

### Create Layer

**From value**

```ts
const ConfigLayer = Layer.succeed(Config, { apiKey: "xxx" });
```

**From effect**

```ts
const DbLayer = Layer.effect(
  Database,
  Effect.gen(function* () {
    const pool = yield* createPool();
    return { query: pool.query, close: pool.close };
  }),
);
```

**From scoped (auto cleanup)**

```ts
const DbLayerScoped = Layer.scoped(
  Database,
  Effect.gen(function* () {
    const pool = yield* Effect.acquireRelease(createPool(), (p) => p.close());
    return { query: pool.query, close: pool.close };
  }),
);
```

**Dynamic with Layer.unwrap**

```ts
import { Config, Layer } from "effect";

export class MessageStore extends Context.Service<
  MessageStore,
  {
    append(message: string): Effect.Effect<void>;
    readonly all: Effect.Effect<ReadonlyArray<string>>;
  }
>()("myapp/MessageStore") {
  static readonly layerInMemory = Layer.effect(
    MessageStore,
    Effect.sync(() => {
      const messages: Array<string> = [];
      return MessageStore.of({
        append: (message) =>
          Effect.sync(() => {
            messages.push(message);
          }),
        all: Effect.sync(() => [...messages]),
      });
    }),
  );

  static readonly layerRemote = (url: URL) =>
    Layer.effect(
      MessageStore,
      Effect.try({
        try: () => {
          // Connect to remote store
          const messages: Array<string> = [];
          return MessageStore.of({
            append: (message) =>
              Effect.sync(() => {
                messages.push(`[${url.host}] ${message}`);
              }),
            all: Effect.sync(() => [...messages]),
          });
        },
        catch: (cause) => new MessageStoreError({ cause }),
      }),
    );

  // Dynamic layer based on config
  static readonly layer = Layer.unwrap(
    Effect.gen(function* () {
      const useInMemory = yield* Config.boolean("MESSAGE_STORE_IN_MEMORY").pipe(
        Config.withDefault(false),
      );

      if (useInMemory) {
        return MessageStore.layerInMemory;
      }

      const remoteUrl = yield* Config.url("MESSAGE_STORE_URL");
      return MessageStore.layerRemote(remoteUrl);
    }),
  );
}
```

### Compose Layers

**Merge**

```ts
const AppLayer = Layer.merge(DbLayer, CacheLayer);
```

**Dependency chain**

```ts
const UserRepoLayer = UserRepository.layerNoDeps.pipe(
  Layer.provide(Database.layer),
);
```

**ProvideMerge (expose both services)**

```ts
const AppLayer = UserRepository.layerNoDeps.pipe(
  Layer.provideMerge(Database.layer),
  // Exposes both UserRepository AND Database
);
```

**Multiple dependencies**

```ts
const AppLayer = Layer.mergeAll(Database.layer, Cache.layer, Logger.layer);
```

### Provide to Effect

```ts
program.pipe(Effect.provide(AppLayer));

// Multiple layers (automatically memoized in v4)
Effect.provide(program, [DbLayer, CacheLayer, LoggerLayer]);

// Provide for specific scope
Effect.provide(program, AppLayer, { local: true });
```

## Context (Context Replacement)

### Direct Service Provision

```ts
Effect.provideService(program, Database, {
  query: () => Effect.succeed([]),
  close: () => Effect.succeed(void 0),
});
```

### Build Context Manually

```ts
import { Context } from "effect";

const map = Context.empty().pipe(
  Context.add(Database, dbImpl),
  Context.add(Cache, cacheImpl),
);

Effect.provide(program, map);
```

## Service References (FiberRef Replacement)

Services with default values use `Context.Reference`:

```ts
import { Context } from "effect";

const LogLevel = Context.Reference<"info" | "warn" | "error">("LogLevel", {
  defaultValue: () => "info" as const,
});

// Use like a service
const program = Effect.gen(function* () {
  const level = yield* LogLevel;
  console.log(level); // "info" (default)
});

// Override with provideService
const withDebug = Effect.provideService(program, LogLevel, "debug");
```

**Feature flags example**

```ts
export const FeatureFlag = Context.Reference<boolean>("myapp/FeatureFlag", {
  defaultValue: () => false,
});
```

## Layer Patterns

### Singleton Layer (memoized)

In v4, layers are automatically memoized across `Effect.provide` calls:

```ts
const DbPoolLayer = Layer.scoped(
  DbPool,
  Effect.acquireRelease(createPool(), (pool) => pool.close()),
);

// Automatically memoized - created once per dependency graph
// Even with multiple Effect.provide calls
```

### Fresh Layer (not memoized)

```ts
const FreshConnection = Layer.scoped(
  Connection,
  Effect.acquireRelease(openConnection(), (conn) => conn.close()),
).pipe(Layer.fresh);
// Created fresh each time it's needed
```

### Local Memoization (v4)

Opt out of shared memoization for isolated layers:

```ts
const main = program.pipe(
  Effect.provide(MyServiceLayer),
  Effect.provide(MyServiceLayer, { local: true }),
);
// Second layer built with local memo map - not shared
```

### Layer for Background Tasks

```ts
import { Layer, Effect } from "effect";

const BackgroundTask = Layer.effectDiscard(
  Effect.gen(function* () {
    yield* Effect.logInfo("Starting background task...");
    yield* Effect.gen(function* () {
      while (true) {
        yield* Effect.sleep("5 seconds");
        yield* Effect.logInfo("Background task running...");
      }
    }).pipe(
      Effect.onInterrupt(() => Effect.logInfo("Background task interrupted")),
      Effect.forkScoped,
    );
  }),
);

// Run with Layer.launch
BackgroundTask.pipe(Layer.launch, NodeRuntime.runMain);
```

## Testing Patterns

### Mock Layer

```ts
const MockDb = Layer.succeed(Database, {
  query: () => Effect.succeed([{ id: 1, name: "Test" }]),
  close: () => Effect.succeed(void 0),
});

const test = program.pipe(Effect.provide(MockDb));
```

### Test Environment with Shared Layers

```ts
import { assert, describe, it, layer } from "@effect/vitest";
import { Array, Effect, Layer, Ref, Context } from "effect";

// Create a test ref service
export class TodoRepoTestRef extends Context.Service<
  TodoRepoTestRef,
  Ref.Ref<Array<Todo>>
>()("app/TodoRepoTestRef") {
  static readonly layer = Layer.effect(
    TodoRepoTestRef,
    Ref.make(Array.empty()),
  );
}

class TodoRepo extends Context.Service<
  TodoRepo,
  {
    create(title: string): Effect.Effect<Todo>;
    readonly list: Effect.Effect<ReadonlyArray<Todo>>;
  }
>()("app/TodoRepo") {
  static readonly layerTest = Layer.effect(
    TodoRepo,
    Effect.gen(function* () {
      const store = yield* TodoRepoTestRef;

      const create = Effect.fn("TodoRepo.create")(function* (title: string) {
        const todos = yield* Ref.get(store);
        const todo = { id: todos.length + 1, title };
        yield* Ref.set(store, [...todos, todo]);
        return todo;
      });

      const list = Ref.get(store);

      return TodoRepo.of({ create, list });
    }),
  ).pipe(Layer.provideMerge(TodoRepoTestRef.layer));
}

// Create shared layer for test block
layer(TodoRepo.layerTest)("TodoRepo", (it) => {
  it.effect("tests repository behavior", () =>
    Effect.gen(function* () {
      const repo = yield* TodoRepo;
      const before = (yield* repo.list).length;
      assert.strictEqual(before, 0);

      yield* repo.create("Write docs");
      const after = (yield* repo.list).length;
      assert.strictEqual(after, 1);
    }),
  );
});
```

## Advanced Patterns

### LayerMap for Dynamic Resources

```ts
import { Effect, Layer, LayerMap, Schema, Context } from "effect";

class DatabasePool extends Context.Service<
  DatabasePool,
  {
    readonly tenantId: string;
    readonly connectionId: number;
    readonly query: (sql: string) => Effect.Effect<ReadonlyArray<UserRecord>>;
  }
>()("app/DatabasePool") {
  static readonly layer = (tenantId: string) =>
    Layer.effect(
      DatabasePool,
      Effect.acquireRelease(
        Effect.sync(() => {
          const connectionId = ++nextConnectionId;
          return DatabasePool.of({
            tenantId,
            connectionId,
            query: Effect.fn("DatabasePool.query")((sql: string) =>
              Effect.succeed([
                { id: 1, email: `admin@${tenantId}.example.com` },
              ]),
            ),
          });
        }),
        (pool) =>
          Effect.logInfo(`Closing pool ${pool.tenantId}#${pool.connectionId}`),
      ),
    );
}

// Extend LayerMap.Service for dynamic resource management
export class PoolMap extends LayerMap.Service<PoolMap>()("app/PoolMap", {
  lookup: (tenantId: string) => DatabasePool.layer(tenantId),
  idleTimeToLive: "1 minute", // Auto-release after idle
}) {}

// Usage
const queryUsersForCurrentTenant = Effect.gen(function* () {
  const pool = yield* DatabasePool;
  return yield* pool.query("SELECT * FROM users");
});

export const program = Effect.gen(function* () {
  yield* queryUsersForCurrentTenant.pipe(Effect.provide(PoolMap.get("acme")));

  // Force rebuild on next access
  yield* PoolMap.invalidate("acme");
}).pipe(Effect.provide(PoolMap.layer));
```

### Conditional Layers

```ts
const ProductionLayers = Layer.mergeAll(RealDb, RedisCache, CloudLogger);

const DevLayers = Layer.mergeAll(LocalDb, MemoryCache, ConsoleLogger);

const AppLayer =
  process.env.NODE_ENV === "production" ? ProductionLayers : DevLayers;
```

## Best Practices

- Use `Context.Service` for service definition
- Name services with app namespace (e.g., "app/Database")
- Build layers explicitly with `Layer.effect`
- Use `Effect.fn` for service methods
- Compose layers at app boundary
- Use scoped layers for resources
- Keep service interfaces small
- Use `yield*` over `Service.use` for visibility
- Prefer `layer` naming over `.Default`

Avoid:

- Accessing services outside Effect
- Creating circular dependencies
- Putting business logic in layers
- Over-layering simple values
- Using `Service.use` when `yield*` is clearer

## External Examples

See full examples:
- [Context.Reference](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/01_effect/02_services/10_reference.ts)
- [Layer Composition](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/01_effect/02_services/20_layer-composition.ts)
- [Layer Unwrap](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/01_effect/02_services/20_layer-unwrap.ts)
