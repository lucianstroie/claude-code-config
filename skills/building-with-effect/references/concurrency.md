# Concurrency Patterns

Fibers, parallelism, racing, and coordination in Effect v4.

See related examples in [effect-smol/ai-docs/src/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/)

## Basic Concurrency

**Parallel execution**

```ts
// Array - runs all in parallel
const results = yield * Effect.all([task1, task2, task3]);

// Struct - runs all in parallel
const data =
  yield *
  Effect.all({
    users: fetchUsers(),
    posts: fetchPosts(),
    comments: fetchComments(),
  });
```

**Control concurrency**

```ts
// Unbounded (all at once)
Effect.all(effects, { concurrency: "unbounded" });

// Sequential (one at a time)
Effect.all(effects, { concurrency: 1 });

// Limited (max N concurrent)
Effect.all(effects, { concurrency: 5 });
```

**ForEach with concurrency**

```ts
const results =
  yield * Effect.forEach(urls, (url) => fetch(url), { concurrency: 10 });
```

## Fibers

### Fork

**Fork as child of current fiber**

```ts
const fiber = yield * Effect.forkChild(longRunningTask);

// Do other work...

const result = yield * Fiber.join(fiber);
```

**Fork options (v4)**

```ts
const fiber = myEffect.pipe(
  Effect.forkChild({
    startImmediately: true, // Execute immediately vs deferred
    uninterruptible: true, // Make uninterruptible
  }),
);
```

### Fork Scoped (unchanged)

**Fork tied to current Scope**

```ts
Effect.scoped(
  Effect.gen(function* () {
    const fiber = yield* Effect.forkScoped(task);
    // Fiber auto-interrupted when scope closes
    return yield* doOtherWork();
  }),
);
```

### Fork Detach (v4: renamed from `forkDaemon`)

**Fork detached from parent lifecycle**

```ts
yield * Effect.forkDetach(backgroundTask);
// Continues even if parent completes
```

### Fork in Scope (unchanged)

**Fork in specific Scope**

```ts
const fiber = yield * Effect.forkIn(task, scope);
```

### Await Fiber

**Important v4 change:** `Fiber` is no longer a subtype of `Effect`. Use explicit methods:

```ts
const fiber = yield * Effect.forkChild(task);

// Wait for completion
const exit = yield * Fiber.await(fiber);

if (Exit.isSuccess(exit)) {
  console.log(exit.value);
}

// Or join directly
const result = yield * Fiber.join(fiber);
```

### Interrupt Fiber

```ts
const fiber = yield * Effect.forkChild(longTask);

// Cancel it
yield * Fiber.interrupt(fiber);
```

### Fork All (removed in v4)

`Effect.forkAll` has been removed. Use individual `forkChild` calls or higher-level combinators:

```ts
// v4 replacement for forkAll
const fibers =
  yield *
  Effect.all(
    [task1, task2, task3].map((t) => Effect.forkChild(t)),
    { concurrency: "unbounded" },
  );
```

## Racing

**First success**

```ts
const result = yield * Effect.race(slow, fast);
// Returns result of whichever completes first
```

**Race all**

```ts
const winner = yield * Effect.raceAll([e1, e2, e3]);
// First to succeed wins, others interrupted
```

**Race with (combine results)**

```ts
const result = yield* Effect.raceWith(task1, task2, {
  onSelfDone: (exit, fiber) => /* ... */,
  onOtherDone: (exit, fiber) => /* ... */
});
```

**Either**

```ts
const result = yield * Effect.either(Effect.race(primary, fallback));
// Get Either<Success, Error> of first to complete
```

## Coordination

### Deferred (v4: not yieldable, use explicit methods)

**Important v4 change:** `Deferred` is no longer yieldable. Use `Deferred.await`:

```ts
const deferred = yield * Deferred.make<string, Error>();

// In one fiber
yield * Deferred.succeed(deferred, "value");

// In another fiber
const value = yield * Deferred.await(deferred);
```

### Queue

```ts
const queue = yield * Queue.bounded<number>(100);

// Producer
yield * Queue.offer(queue, 42);

// Consumer
const value = yield * Queue.take(queue);

// Batch operations
yield * Queue.offerAll(queue, [1, 2, 3]);
const batch = yield * Queue.takeUpTo(queue, 10);
```

### Ref (v4: not yieldable, use explicit methods)

**Important v4 change:** `Ref` is no longer yieldable. Use `Ref.get`, `Ref.set`, etc.:

```ts
const counter = yield * Ref.make(0);

// Update
yield * Ref.update(counter, (n) => n + 1);

// Get
const value = yield * Ref.get(counter);

// Modify (get + update atomically)
const prev = yield * Ref.modify(counter, (n) => [n, n + 1]);
```

### Semaphore

```ts
const sem = yield * Semaphore.make(5);

// Acquire permits
yield * Semaphore.withPermit(sem, () => criticalSection());

// Multiple permits
yield * Semaphore.withPermits(sem, 3, () => heavyOperation());
```

### Latch

```ts
const latch = yield * Latch.make(3);

// Wait until opened
yield * Latch.await(latch);

// Open (can only happen once)
yield * Latch.open(latch);
```

## Interruption

**Make interruptible**

```ts
Effect.interruptible(longRunningTask);
```

**Uninterruptible region**

```ts
Effect.uninterruptible(criticalSection);
```

**Handle interruption**

```ts
task.pipe(Effect.onInterrupt(() => cleanup()));
```

**Ensuring cleanup**

```ts
Effect.acquireUseRelease(
  acquire,
  (resource) => use(resource),
  (resource) => cleanup(resource),
);
// Cleanup runs even if interrupted
```

## Fiber Supervision

**Supervise children**

```ts
Effect.supervised(
  Effect.gen(function* () {
    yield* Effect.forkChild(child1);
    yield* Effect.forkChild(child2);
    // Supervisor monitors all forked children
  }),
);
```

**Custom supervisor**

```ts
const supervisor = Supervisor.track;

Effect.supervised(program, supervisor);
```

## Timeouts

**Basic timeout**

```ts
effect.pipe(Effect.timeout("30 seconds"));
// Returns Option<A>
```

**Timeout with error**

```ts
effect.pipe(
  Effect.timeoutFail({
    duration: "30 seconds",
    onTimeout: () => new TimeoutError(),
  }),
);
```

**Timeout to result**

```ts
const result =
  yield *
  effect.pipe(
    Effect.timeoutTo({
      duration: "5 seconds",
      onSuccess: (a) => `Success: ${a}`,
      onTimeout: () => "Timed out",
    }),
  );
```

## Scheduling

**Repeat**

```ts
import { Schedule } from "effect";

// Fixed times
effect.pipe(Effect.repeat({ times: 5 }));

// Forever
effect.pipe(Effect.repeat(Schedule.forever));

// With schedule
effect.pipe(Effect.repeat(Schedule.spaced("1 second")));
```

**Common schedules**

```ts
// Fixed intervals
Schedule.spaced("1 second");

// Exponential backoff
Schedule.exponential("100 millis", 2.0);

// Fibonacci
Schedule.fibonacci("100 millis");

// With max retries
Schedule.spaced("1 second").pipe(Schedule.upTo("1 minute"));
```

**Retry with schedule**

```ts
effect.pipe(Effect.retry(Schedule.exponential("100 millis")));
```

## Context References

Fiber-local state is now handled by `Context.Reference`:

```ts
import { Effect, Context, References } from "effect";

// Built-in references
const program = Effect.gen(function* () {
  const level = yield* References.CurrentLogLevel;
  const concurrency = yield* References.CurrentConcurrency;
  console.log(level, concurrency);
});

// Custom reference
const RequestId = Context.Reference<string>("RequestId", {
  defaultValue: () => "",
});

// Override scoped value
const withRequestId = Effect.provideService(program, RequestId, "req-123");
```

## Batching

**Request batching**

```ts
import { RequestResolver, Request } from "effect";

interface GetUser extends Request.Request<User, Error> {
  readonly id: string;
}

const GetUser = Request.tagged<GetUser>("GetUser");

const resolver = RequestResolver.makeBatched((requests: Array<GetUser>) =>
  Effect.gen(function* () {
    const users = yield* fetchUsersBatch(requests.map((r) => r.id));
    yield* Effect.forEach(requests, (req, i) => Request.succeed(req, users[i]));
  }),
);

// Usage
const program = Effect.gen(function* () {
  const users = yield* Effect.all(
    [
      Effect.request(GetUser({ id: "1" }), resolver),
      Effect.request(GetUser({ id: "2" }), resolver),
      Effect.request(GetUser({ id: "3" }), resolver),
    ],
    { batching: true },
  );
  // All 3 requests batched into single fetchUsersBatch call
});
```

## Patterns

**Worker pool**

```ts
const pool =
  yield *
  Effect.forEach(Array.range(1, 10), () => Effect.forkChild(worker()), {
    concurrency: "unbounded",
  });

// Send work to pool
yield * Effect.forEach(jobs, (job) => processJob(job), { concurrency: 10 });
```

**Pipeline**

```ts
const pipeline = <A, B, C>(input: Array<A>) =>
  Effect.gen(function* () {
    const stage1 = yield* Effect.forEach(input, process1, { concurrency: 5 });

    const stage2 = yield* Effect.forEach(stage1, process2, { concurrency: 3 });

    return stage2;
  });
```

**Circuit breaker**

```ts
class CircuitBreaker {
  private failures = 0;
  private isOpen = false;

  call<A, E>(effect: Effect.Effect<A, E>) {
    return Effect.gen(function* () {
      if (this.isOpen) {
        return yield* Effect.fail(new CircuitOpenError());
      }

      const result = yield* Effect.either(effect);

      if (Either.isLeft(result)) {
        this.failures++;
        if (this.failures >= threshold) {
          this.isOpen = true;
        }
      } else {
        this.failures = 0;
      }

      return yield* result;
    });
  }
}
```

## Anti-Patterns to Avoid

### For-Loop with forkChild

**// Bad** — Sequential fork in a loop:

```ts
// This is an anti-pattern - forks are sequential, not concurrent
const fibers: Fiber.Fiber<void>[] = [];
for (const task of items) {
  const fiber = yield* Effect.forkChild(process(task));
  fibers.push(fiber);
}
// This runs ONE at a time, not in parallel!
```

**// Good** — Use Effect.forEach with concurrency:

```ts
// All items processed concurrently with unbounded concurrency
const results = yield* Effect.forEach(items, process, {
  concurrency: "unbounded",
});
```

**// Good** — Use Effect.forEach with limited concurrency:

```ts
// Process up to 10 items concurrently
const results = yield* Effect.forEach(items, process, {
  concurrency: 10,
});
```

### Blocking Loop Without Concurrency

**// Bad** — Blocking loop defeats concurrency:

```ts
for (const item of items) {
  yield* process(item); // Sequential!
}
```

**// Good** — Use forEach with concurrency:

```ts
yield* Effect.forEach(items, process, { concurrency: 5 });
```

### Forgetting to Join Fibers

**// Bad** — Fire and forget (resource leak):

```ts
yield* Effect.forkChild(longRunningTask);
// Forgot to join! Fiber may never complete, resources leak
```

**// Good** — Always join fibers:

```ts
const fiber = yield* Effect.forkChild(longRunningTask);
// ... do other work ...
const result = yield* Fiber.join(fiber);
```

**// Good** — Use joinAll for multiple fibers:

```ts
const fibers = yield* Effect.all(
  items.map((item) => Effect.forkChild(process(item))),
  { concurrency: "unbounded" },
);
const results = yield* Fiber.joinAll(fibers);
```

### Using forkChild Without Scope

**// Bad** — Orphan fiber (not tied to scope):

```ts
const fiber = yield* Effect.forkChild(backgroundTask);
// fiber may be garbage collected or interrupted unexpectedly
```

**// Good** — Use forkScoped or scoped context:

```ts
yield* Effect.scoped(
  Effect.gen(function* () {
    const fiber = yield* Effect.forkScoped(backgroundTask);
    // fiber tied to scope, will be interrupted if scope closes
  }),
);
```

### Mixing Promise and Effect Concurrency

**// Bad** — Promise.all doesn't integrate with Effect fibers:

```ts
const results = await Promise.all(items.map(process)); // No Effect integration!
```

**// Good** — Use Effect.forEach:

```ts
const results = yield* Effect.forEach(items, process, { concurrency: 10 });
```

---

## Best Practices

Fork long-running tasks
Use bounded queues for backpressure
Clean up forked fibers (forkScoped)
Handle interruption in critical sections
Use Semaphore for resource pools
Batch similar requests together

Avoid:

- Blocking fibers unnecessarily
- Forgetting to interrupt unused fibers
- Using unbounded parallelism for large datasets
- Ignoring backpressure signals
- Racing effects that should run sequentially
