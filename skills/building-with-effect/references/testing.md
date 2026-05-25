# Testing

Testing Effect programs with @effect/vitest.

See full examples:
- [Effect Tests](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/09_testing/10_effect-tests.ts)
- [Layer Tests](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/09_testing/20_layer-tests.ts)

## Setup

### Install

```bash
npm install --save-dev @effect/vitest
```

### Configure

```ts
// vitest.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["**/*.test.ts"],
    globals: true,
  },
});
```

## Basic Tests

### Effect Tests

```ts
import { assert, describe, it } from "@effect/vitest";
import { Effect, Schema } from "effect";

describe("basic tests", () => {
  it.effect("runs Effect code with assert helpers", () =>
    Effect.gen(function* () {
      const upper = ["ada", "lin"].map((name) => name.toUpperCase());

      assert.deepStrictEqual(upper, ["ADA", "LIN"]);
      assert.strictEqual(upper.length, 2);
      assert.isTrue(upper.includes("ADA"));
    }),
  );
});
```

### Parameterized Tests

```ts
describe("parameterized tests", () => {
  it.effect.each([
    { input: " Ada ", expected: "ada" },
    { input: " Lin ", expected: "lin" },
    { input: " Nia ", expected: "nia" },
  ])("normalizes %#", ({ input, expected }) =>
    Effect.gen(function* () {
      assert.strictEqual(input.trim().toLowerCase(), expected);
    }),
  );
});
```

## Time Control

### TestClock

```ts
import { Fiber } from "effect";
import { TestClock } from "effect/testing";

describe("time control", () => {
  it.effect("controls time with TestClock", () =>
    Effect.gen(function* () {
      const fiber = yield* Effect.forkChild(
        Effect.sleep(60000).pipe(Effect.as("done" as const)),
      );

      // Move virtual time forward
      yield* TestClock.adjust(60000);

      const value = yield* Fiber.join(fiber);
      assert.strictEqual(value, "done");
    }),
  );
});
```

### Real Time

```ts
describe("real time", () => {
  it.live("uses real runtime services", () =>
    Effect.gen(function* () {
      const startedAt = Date.now();
      yield* Effect.sleep(1);
      assert.isTrue(Date.now() >= startedAt);
    }),
  );
});
```

## Property-Based Testing

### Schema-Based Properties

```ts
describe("property-based", () => {
  it.effect.prop("reversing twice is identity", [Schema.String], ([value]) =>
    Effect.gen(function* () {
      const reversedTwice = value.split("").reverse().reverse().join("");
      assert.strictEqual(reversedTwice, value);
    }),
  );
});
```

## Testing Services

### With Shared Layers

```ts
import { Array, Effect, Layer, Ref, Context } from "effect";
import { assert, describe, it, layer } from "@effect/vitest";

interface Todo {
  readonly id: number;
  readonly title: string;
}

// Test ref for shared state
class TodoRepoTestRef extends Context.Service<
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
  it.effect("creates todo", () =>
    Effect.gen(function* () {
      const repo = yield* TodoRepo;
      const before = (yield* repo.list).length;
      assert.strictEqual(before, 0);

      yield* repo.create("Write docs");
      const after = (yield* repo.list).length;
      assert.strictEqual(after, 1);
    }),
  );

  it.effect("layer is shared between tests", () =>
    Effect.gen(function* () {
      const repo = yield* TodoRepo;
      const before = (yield* repo.list).length;
      assert.strictEqual(before, 1); // From previous test

      yield* repo.create("Write more docs");
      const after = (yield* repo.list).length;
      assert.strictEqual(after, 2);
    }),
  );
});
```

### Testing Higher-Level Services

```ts
describe("TodoService", () => {
  it.effect("tests higher-level service logic", () =>
    Effect.gen(function* () {
      const ref = yield* TodoRepoTestRef;
      const service = yield* TodoService;

      const count = yield* service.addAndCount("Review docs");
      const titles = yield* service.titles;

      assert.isTrue(count >= 1);
      assert.isTrue(titles.some((title) => title.includes("Review docs")));

      // Access test ref directly
      const todos = yield* Ref.get(ref);
      assert.isTrue(todos.length >= 1);
    }).pipe(Effect.provide(TodoService.layerTest)),
  );
});
```

## Testing Errors

### Expecting Failures

```ts
describe("error handling", () => {
  it.effect("expects failure", () =>
    Effect.gen(function* () {
      const result = yield* failingEffect.pipe(
        Effect.flip, // Swap success/error channels
      );

      assert.instanceOf(result, MyError);
    }),
  );
});
```

### Testing Error Recovery

```ts
describe("error recovery", () => {
  it.effect("recovers from errors", () =>
    Effect.gen(function* () {
      const result = yield* failingOperation.pipe(
        Effect.orElse(() => Effect.succeed("recovered")),
      );

      assert.strictEqual(result, "recovered");
    }),
  );
});
```

## Testing Concurrency

### Fork and Join

```ts
describe("concurrency", () => {
  it.effect("forks and joins fibers", () =>
    Effect.gen(function* () {
      const fiber1 = yield* Effect.forkChild(Effect.succeed(1));
      const fiber2 = yield* Effect.forkChild(Effect.succeed(2));

      const result1 = yield* Fiber.join(fiber1);
      const result2 = yield* Fiber.join(fiber2);

      assert.strictEqual(result1, 1);
      assert.strictEqual(result2, 2);
    }),
  );
});
```

### Racing

```ts
describe("racing", () => {
  it.effect("races effects", () =>
    Effect.gen(function* () {
      const result = yield* Effect.race(
        Effect.sleep("1 second").pipe(Effect.as("slow")),
        Effect.succeed("fast"),
      );

      assert.strictEqual(result, "fast");
    }),
  );
});
```

## Testing Resources

### acquireRelease

```ts
describe("resources", () => {
  it.effect("cleans up resources", () =>
    Effect.gen(function* () {
      let cleanedUp = false;

      const result = yield* Effect.acquireUseRelease(
        Effect.succeed("resource"),
        (res) => Effect.succeed(`used ${res}`),
        () =>
          Effect.sync(() => {
            cleanedUp = true;
          }),
      );

      assert.strictEqual(result, "used resource");
      assert.isTrue(cleanedUp);
    }),
  );
});
```

## Testing Streams

```ts
import { Chunk, Stream } from "effect";

describe("streams", () => {
  it.effect("collects stream values", () =>
    Effect.gen(function* () {
      const result = yield* Stream.make(1, 2, 3).pipe(
        Stream.map((n) => n * 2),
        Stream.runCollect,
      );

      assert.deepStrictEqual(Chunk.toArray(result), [2, 4, 6]);
    }),
  );
});
```

## Testing Retries

```ts
describe("retries", () => {
  it.effect("retries with schedule", () =>
    Effect.gen(function* () {
      let attempts = 0;

      const result = yield* Effect.gen(function* () {
        attempts++;
        if (attempts < 3) {
          return yield* Effect.fail("not yet");
        }
        return "success";
      }).pipe(Effect.retry({ times: 3 }));

      assert.strictEqual(result, "success");
      assert.strictEqual(attempts, 3);
    }),
  );
});
```

## Best Practices

1. **Use it.effect** for all Effect-based tests
2. **Use layer()** for sharing layers across tests
3. **Use TestClock** for time-dependent tests
4. **Use Effect.flip** to test error cases
5. **Use it.live sparingly** - prefer TestClock
6. **Create test refs** for shared state in tests
7. **Test error recovery** paths explicitly
8. **Use property-based testing** for invariants

## Common Patterns

### Before/After Hooks

```ts
describe("with setup", () => {
  let sharedResource: Resource;

  beforeAll(() => {
    sharedResource = createResource();
  });

  afterAll(() => {
    sharedResource.cleanup();
  });

  it.effect("uses shared resource", () =>
    Effect.gen(function* () {
      yield* sharedResource.doSomething();
    }),
  );
});
```

### Test Utilities

```ts
// Helper for creating test effects
const testEffect = <E, A>(effect: Effect.Effect<A, E>) =>
  effect.pipe(Effect.provide(TestLayer));

// Usage
it.effect("uses helper", () =>
  testEffect(
    Effect.gen(function* () {
      // Test code
    }),
  ),
);
```
