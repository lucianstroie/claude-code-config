# API Comparison

Effect v4 vs Promise, fp-ts, and ZIO.

See related examples in [effect-smol/ai-docs/src/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/)

## Effect vs Promise

**Creation**
```ts
// Promise
const p = Promise.resolve(42);

// Effect
const e = Effect.succeed(42);
```

**Chaining**
```ts
// Promise
promise.then(x => x * 2);

// Effect
effect.pipe(Effect.map(x => x * 2));
```

**Error handling**
```ts
// Promise (untyped)
promise.catch(err => handle(err));

// Effect (typed)
effect.pipe(
  Effect.catch((err: MyError) => handle(err))
);
```

**Async/await vs gen**
```ts
// Promise
async function program() {
  const a = await fetchA();
  const b = await fetchB();
  return a + b;
}

// Effect
const program = Effect.gen(function* () {
  const a = yield* fetchA();
  const b = yield* fetchB();
  return a + b;
});
```

**Key differences**
- Promises eager, Effects lazy
- Promises one-shot, Effects multi-shot
- Promises untyped errors, Effects typed
- Promises no interruption, Effects interruptible
- Promises no requirements tracking

## Effect vs fp-ts

**Type representation**
```ts
// fp-ts
TaskEither<Error, Value>
ReaderTaskEither<Context, Error, Value>

// Effect
Effect<Value, Error, Context>
```

**Basic operations**
```ts
// fp-ts
import * as TE from "fp-ts/TaskEither";

pipe(
  TE.right(42),
  TE.map(x => x * 2)
);

// Effect
Effect.succeed(42).pipe(
  Effect.map(x => x * 2)
);
```

**Error handling**
```ts
// fp-ts
pipe(
  effect,
  TE.mapLeft(e => new CustomError(e))
);

// Effect
effect.pipe(
  Effect.mapError(e => new CustomError(e))
);
```

**Services (v4: Context pattern)**
```ts
// fp-ts (manual)
interface Has<T> { _tag: unique symbol }
type AppEnv = Has<Database> & Has<Logger>;

// Effect v4 (built-in)
import { Effect, Context, Layer } from "effect";

class Database extends Context.Service<Database>()("Database", {
  make: Effect.gen(function* () {
    // ... initialization
    return { query: (sql: string) => Effect.succeed([]) };
  })
}) {
  static readonly layer = Layer.effect(this, this.make);
}
```

**Key differences**
- Effect has native services/layers via Context
- Effect has runtime system
- Effect has concurrency primitives
- Effect has resource management
- fp-ts more lightweight

## Effect vs ZIO

**Environment**
```scala
// ZIO (Scala)
ZIO[Console with Logger, Error, Value]

// Effect
Effect<Value, Error, Console | Logger>
```

**Type parameter order**
```scala
// ZIO
ZIO[R, E, A]

// Effect  
Effect<A, E, R>
```

**Service pattern (v4: Context)**
```scala
// ZIO
trait UserRepo {
  def find(id: String): IO[Error, User]
}

object UserRepo {
  def find(id: String): ZIO[UserRepo, Error, User] =
    ZIO.serviceWithZIO[UserRepo](_.find(id))
}

// Effect v4
import { Effect, Context, Layer } from "effect";

class UserRepo extends Context.Service<UserRepo>()("UserRepo", {
  make: Effect.succeed({
    find: (id: string) => Effect.succeed(user)
  })
}) {
  static readonly layer = Layer.effect(this, this.make);
}
```

**For comprehension vs gen**
```scala
// ZIO
for {
  a <- fetchA()
  b <- fetchB()
} yield a + b

// Effect
Effect.gen(function* () {
  const a = yield* fetchA();
  const b = yield* fetchB();
  return a + b;
});
```

**Key differences**
- Environment: intersection (ZIO) vs union (Effect)
- Type params reversed
- ZIO in Scala, Effect in TypeScript
- Similar concepts, different ecosystems

## Common Equivalents

### fp-ts to Effect

| fp-ts | Effect |
|-------|--------|
| `TaskEither<E, A>` | `Effect<A, E>` |
| `ReaderTaskEither<R, E, A>` | `Effect<A, E, R>` |
| `Task<A>` | `Effect<A>` |
| `IO<A>` | `Effect.sync(() => A)` |
| `Option<A>` | `Option<A>` |
| `Either<E, A>` | `Result<A, E>` |
| `map` | `map` |
| `chain` | `flatMap` / `andThen` |
| `mapLeft` | `mapError` |
| `fold` | `match` |

### Promise to Effect

| Promise | Effect |
|---------|--------|
| `Promise.resolve(a)` | `Effect.succeed(a)` |
| `Promise.reject(e)` | `Effect.fail(e)` |
| `promise.then(f)` | `effect.pipe(Effect.map(f))` |
| `promise.catch(f)` | `effect.pipe(Effect.catch(f))` |
| `Promise.all([...])` | `Effect.all([...])` |
| `Promise.race([...])` | `Effect.race(...)` |
| `async/await` | `Effect.gen` |

## Key v4 Changes

### Context Pattern

In v4, types like `Option` and `Config` are `Yieldable` but not `Effect` subtypes:

```ts
// Works in generators
Effect.gen(function* () {
  const value = yield* Option.some(42);
  const config = yield* Config.string("API_KEY");
});

// Must convert for combinators
Effect.map(Option.some(42).asEffect(), x => x + 1);
```

### Non-Yieldable Types

In v4, `Ref`, `Deferred`, and `Fiber` are no longer Effect subtypes:

```ts
const ref = yield* Ref.make(0);
const value = yield* Ref.get(ref);  // Use explicit method
```

## Summary

Effect v4 maintains the same core programming model while improving:
- **Type safety** via Yieldable trait
- **Explicitness** in service dependencies
- **Consistency** with Context replacing Context
- **Performance** with automatic fiber keep-alive
- **Simplicity** with unified package versioning

The main migration effort is in service definitions (Context → Context) and understanding which types are Yieldable vs Effect subtypes.
