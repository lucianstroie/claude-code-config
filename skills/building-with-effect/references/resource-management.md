# Resource Management

Safe resource acquisition and cleanup in Effect v4.

See related examples in [effect-smol/ai-docs/src/01_effect/04_resources/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/01_effect/04_resources/)

## Basic Pattern

**acquireRelease**

```ts
Effect.acquireRelease(
  acquire, // Effect that gets resource
  release, // Cleanup (runs even if interrupted)
);
```

**acquireUseRelease**

```ts
Effect.acquireUseRelease(
  openConnection(),
  (conn) => query(conn),
  (conn) => conn.close(),
);
```

## Resource Pattern Selector

Choose the right resource management pattern based on your scenario:

| Scenario | Pattern | Why |
|----------|---------|-----|
| External resource (file, connection, socket) | `acquireUseRelease` | Guarantees cleanup even on interruption |
| Shared mutable state with atomic updates | `Ref` | Thread-safe state management |
| Cleanup within existing scope | `addFinalizer` | Add cleanup to already-acquired resource |
| In-memory cache with TTL | `Ref` | Mutable reference for cache map |
| Connection pool | `acquireUseRelease` + pool pattern | Lifecycle management for pool members |
| Temporary resource in service method | `acquireUseRelease` | Scoped to method execution |

### When to Use Each Pattern

**acquireUseRelease** — For resources with lifecycle needs:

```ts
// Good — file handle with guaranteed cleanup
const readFile = (path: string) =>
  Effect.acquireUseRelease(
    Effect.sync(() => fs.openSync(path, "r")),  // acquire
    (fd) => Effect.sync(() => fs.readFileSync(fd, "utf-8")),  // use
    (fd) => Effect.sync(() => fs.closeSync(fd)),  // release
  );
```

**Ref** — For shared mutable state:

```ts
// Good — cache state with atomic updates
const cacheRef = yield* Ref.make<Map<string, string>>(new Map());

const getOrSet = (key: string, generator: () => Effect<string>) =>
  Effect.gen(function* () {
    const cache = yield* Ref.get(cacheRef);
    const existing = cache.get(key);
    if (existing) return existing;
    
    const value = yield* generator();
    yield* Ref.update(cacheRef, (m) => m.set(key, value));
    return value;
  });
```

**addFinalizer** — For cleanup side effects:

```ts
// Good — add cleanup to resource acquired elsewhere
Effect.gen(function* () {
  const resource = yield* acquireResource();
  yield* Effect.addFinalizer(() => cleanup(resource));
  // Use resource...
});
```

### Common Mistakes

**// Bad** — DON'T use Ref when you need acquireUseRelease:

```ts
// Wrong - Ref doesn't provide cleanup guarantees
const badFile = Ref.make<number>(0);
yield* Ref.update(badFile, () => fs.openSync("file.txt", "r")); // No cleanup!
```

**// Good** — use acquireUseRelease for file handles:

```ts
const readFile = Effect.acquireUseRelease(
  Effect.sync(() => fs.openSync("file.txt", "r")),
  (fd) => Effect.sync(() => fs.readFileSync(fd, "utf-8")),
  (fd) => Effect.sync(() => fs.closeSync(fd)),
);
```

**// Bad** — DON'T use addFinalizer without existing scope:

```ts
// Wrong - finalizer needs a scope
yield* Effect.addFinalizer(() => cleanup()); // No scope!
```

**// Good** — use addFinalizer within scoped context:

```ts
Effect.scoped(
  Effect.gen(function* () {
    const resource = yield* acquireResource();
    yield* Effect.addFinalizer(() => cleanup(resource));
  }),
);
```

---

## Scope

**Scoped resources**

```ts
const scoped = Effect.acquireRelease(openFile("data.txt"), (file) =>
  file.close(),
);

// Use within scope
Effect.scoped(
  Effect.gen(function* () {
    const file = yield* scoped;
    const data = yield* file.read();
    return data;
  }),
);
// File automatically closed when scope exits
```

**Multiple resources**

```ts
Effect.scoped(
  Effect.gen(function* () {
    const db = yield* Effect.acquireRelease(openDb(), (d) => d.close());

    const cache = yield* Effect.acquireRelease(openCache(), (c) => c.close());

    // Use both resources
    const result = yield* processData(db, cache);
    return result;
  }),
);
// Both cleaned up in reverse order
```

## Scope.provide

**Provide scope to effect**

```ts
import { Effect, Scope } from "effect";

const program = Effect.gen(function* () {
  const scope = yield* Scope.make();

  yield* Scope.provide(scope)(myEffect);
});

// Data-first form
Scope.provide(myEffect, scope);

// Curried form (data-last)
myEffect.pipe(Scope.provide(scope));
```

## Additive Scopes

**Add cleanup to existing scope**

```ts
Effect.gen(function* () {
  const scope = yield* Scope.make();

  // Add resources to scope
  const file = yield* pipe(
    openFile("data.txt"),
    Effect.tap((f) => Scope.addFinalizer(scope, () => f.close())),
  );

  // Use file...

  // Close scope (runs finalizers)
  yield* Scope.close(scope, Exit.succeed(void 0));
});
```

## Pool Pattern

**Connection pool**

```ts
class ConnectionPool {
  private readonly pool: Array<Connection> = [];

  acquire() {
    return Effect.acquireRelease(
      Effect.sync(() => this.pool.pop() ?? createConnection()),
      (conn) => Effect.sync(() => this.pool.push(conn)),
    );
  }
}

// Usage
const pool = new ConnectionPool();

Effect.scoped(
  Effect.gen(function* () {
    const conn = yield* pool.acquire();
    return yield* query(conn);
  }),
);
```

## Layers with Resources (v4: Context pattern)

**Scoped layer**

```ts
import { Effect, Layer, Context } from "effect";

const DbLayer = Layer.effect(
  Database,
  Effect.gen(function* () {
    const pool = yield* Effect.acquireRelease(createPool(), (p) => p.close());

    return {
      query: (sql) => pool.query(sql),
      close: () => Effect.void,
    };
  }),
);
// Pool automatically closed when layer is released
```

**Service with scoped resources (v4)**

```ts
class HttpClient extends Context.Service<HttpClient>()("HttpClient", {
  make: Effect.gen(function* () {
    const client = yield* Effect.acquireRelease(
      Effect.sync(() => new Client()),
      (c) => Effect.sync(() => c.close()),
    );

    return {
      get: (url) => Effect.tryPromise(() => client.fetch(url)),
    };
  }),
}) {
  static readonly layer = Layer.scoped(this, this.make);
}
```

## Finalizers

**Add cleanup actions**

```ts
Effect.gen(function* () {
  yield* Effect.addFinalizer(() => Console.log("Cleanup 1"));

  yield* Effect.addFinalizer(() => Console.log("Cleanup 2"));

  return "done";
});
// Finalizers run in reverse order on success/failure/interruption
```

**Conditional finalizers**

```ts
Effect.gen(function* () {
  const resource = yield* allocateResource();

  if (shouldCleanup) {
    yield* Effect.addFinalizer(() => cleanup(resource));
  }

  return resource;
});
```

## Ensuring Cleanup

**onExit**

```ts
effect.pipe(
  Effect.onExit((exit) =>
    Exit.match(exit, {
      onFailure: (cause) => logError(cause),
      onSuccess: (value) => logSuccess(value),
    }),
  ),
);
```

**onError**

```ts
effect.pipe(
  Effect.onError((cause) => Console.error(`Failed: ${Cause.pretty(cause)}`)),
);
```

**onInterrupt**

```ts
effect.pipe(Effect.onInterrupt(() => Console.log("Task was interrupted")));
```

## Common Patterns

**File operations**

```ts
const processFile = (path: string) =>
  Effect.acquireUseRelease(
    Effect.sync(() => fs.openSync(path, "r")),
    (fd) => Effect.sync(() => fs.readFileSync(fd, "utf-8")),
    (fd) => Effect.sync(() => fs.closeSync(fd)),
  );
```

**Database transaction**

```ts
const transaction = <A, E>(effect: Effect.Effect<A, E, Database>) =>
  Effect.acquireUseRelease(
    Effect.gen(function* () {
      const db = yield* Database;
      yield* db.beginTransaction();
      return db;
    }),
    () => effect,
    (db, exit) => (Exit.isSuccess(exit) ? db.commit() : db.rollback()),
  );
```

**Lock/Mutex pattern**

```ts
class Mutex {
  private locked = false;

  acquire() {
    return Effect.acquireRelease(
      Effect.gen(function* () {
        while (this.locked) {
          yield* Effect.sleep("10 millis");
        }
        this.locked = true;
      }),
      () =>
        Effect.sync(() => {
          this.locked = false;
        }),
    );
  }
}

// Usage
Effect.scoped(
  Effect.gen(function* () {
    yield* mutex.acquire();
    // Critical section
  }),
);
```

## Resource Leak Prevention

**Always use acquireRelease**

```ts
// ❌ Bad - resource may leak
Effect.gen(function* () {
  const resource = yield* allocate();
  const result = yield* use(resource);
  yield* cleanup(resource); // May not run if error/interrupt
  return result;
});

// ✅ Good - cleanup guaranteed
Effect.acquireUseRelease(
  allocate(),
  (resource) => use(resource),
  (resource) => cleanup(resource),
);
```

**Nested resources**

```ts
Effect.scoped(
  Effect.gen(function* () {
    const db = yield* Effect.acquireRelease(openDb(), (d) => d.close());

    const cache = yield* Effect.acquireRelease(openCache(), (c) => c.close());

    const session = yield* Effect.acquireRelease(createSession(db), (s) =>
      s.destroy(),
    );

    return yield* process(db, cache, session);
  }),
);
// Cleanup order: session, cache, db
```

## Best Practices

Use acquireRelease for resource management
Put cleanup in finally-like finalizers  
Use scoped for multiple resources
Release in reverse acquisition order
Make cleanup idempotent
Use layers for app-level resources

Avoid:

- Manually managing cleanup
- Forgetting interruption cases
- Leaking scoped resources
- Ignoring cleanup failures
- Nesting try/finally (use acquireRelease)
