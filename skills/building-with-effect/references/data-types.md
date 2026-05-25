# Effect Data Types

Common data structures in Effect v4 ecosystem.

See related examples in [effect-smol/ai-docs/src/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/)

## Option

**Represents optional values**

```ts
import { Option } from "effect";

// Create
const some = Option.some(42);
const none = Option.none();

// From nullable
Option.fromNullable(value); // null|undefined -> None

// Check
Option.isSome(opt);
Option.isNone(opt);

// Access value
Option.getOrElse(opt, () => defaultValue);
Option.getOrThrow(opt); // throws if None

// Transform
Option.map(opt, (n) => n * 2);
Option.flatMap(opt, (n) => Option.some(n + 1));

// Match
Option.match(opt, {
  onNone: () => "empty",
  onSome: (value) => `value: ${value}`,
});

// Gen
Option.gen(function* () {
  const a = yield* Option.some(10);
  const b = yield* Option.some(20);
  return a + b;
});
```

**Important v4 change:** Option is Yieldable but not an Effect subtype:

```ts
// In generators - works as before
Effect.gen(function* () {
  const value = yield* Option.some(42);
  return value;
});

// In combinators - must convert explicitly
Effect.map(Option.some(42).asEffect(), (n) => n + 1);
```

## Result (formerly Either in v3)

**Represents success or failure with eager, pure evaluation**

In v4, `Either` has been renamed to `Result`. Unlike `Effect`, `Result` evaluates **eagerly and synchronously** with no side effects.

```ts
import { Result } from "effect";

// Create
const ok = Result.succeed(42);
const err = Result.fail("error");

// Check
Result.isSuccess(result);
Result.isFailure(result);

// Transform
Result.map(result, (n) => n * 2);
Result.flatMap(result, (n) => Result.succeed(n + 1));

// Match
Result.match(result, {
  onFailure: (error) => `Error: ${error}`,
  onSuccess: (value) => `Success: ${value}`,
});
```

**See [data-type-result.md](data-type-result.md) for comprehensive reference** — covering all API surface including generators, do notation, filtering, transposing, Effect interoperability, and more.

## Chunk

**Immutable, performant array**

```ts
import { Chunk } from "effect";

// Create
const chunk = Chunk.make(1, 2, 3);
Chunk.fromIterable([1, 2, 3]);
Chunk.empty();

// Operations (all return new Chunk)
Chunk.append(chunk, 4);
Chunk.prepend(chunk, 0);
Chunk.concat(chunk1, chunk2);
Chunk.take(chunk, 2);
Chunk.drop(chunk, 1);

// Transform
Chunk.map(chunk, (n) => n * 2);
Chunk.filter(chunk, (n) => n > 1);
Chunk.flatMap(chunk, (n) => Chunk.make(n, n));

// Access
Chunk.get(chunk, 0); // Option<A>
Chunk.unsafeGet(chunk, 0); // A (unsafe)

// Convert
Chunk.toReadonlyArray(chunk);
```

## HashSet

**Immutable set with value equality**

```ts
import { HashSet } from "effect";

// Create
const set = HashSet.fromIterable([1, 2, 3, 2]); // {1,2,3}
HashSet.make(1, 2, 3);
HashSet.empty();

// Operations
HashSet.add(set, 4);
HashSet.remove(set, 2);
HashSet.has(set, 2);
HashSet.size(set);

// Set operations
HashSet.union(set1, set2);
HashSet.intersection(set1, set2);
HashSet.difference(set1, set2);

// Transform
HashSet.map(set, (n) => n * 2);
HashSet.filter(set, (n) => n > 1);
```

## HashMap

**Immutable map with value equality**

```ts
import { HashMap } from "effect";

// Create
const map = HashMap.make(["key1", "value1"], ["key2", "value2"]);
HashMap.empty();

// Operations
HashMap.set(map, "key3", "value3");
HashMap.remove(map, "key1");
HashMap.get(map, "key1"); // Option<V>
HashMap.has(map, "key1");
HashMap.size(map);

// Iteration
HashMap.keys(map);
HashMap.values(map);

// Transform
HashMap.map(map, (v, k) => v.toUpperCase());
HashMap.filter(map, (v, k) => v.length > 3);
```

## Cause (v4: Flattened Structure)

In v4, `Cause<E>` has been flattened to a simple wrapper around an array of `Reason` values:

```ts
interface Cause<E> {
  readonly reasons: ReadonlyArray<Reason<E>>;
}

type Reason<E> = Fail<E> | Die | Interrupt;
```

**Creating causes**

```ts
import { Cause } from "effect";

// Individual reasons
Cause.fail(error);
Cause.die(defect);
Cause.interrupt(fiberId);

// Combine causes (replaces sequential/parallel)
Cause.combine(cause1, cause2);

// Empty cause
Cause.empty;
```

**Accessing reasons**

```ts
const handle = (cause: Cause.Cause<string>) => {
  // Iterate over flat reasons array
  for (const reason of cause.reasons) {
    switch (reason._tag) {
      case "Fail":
        return reason.error;
      case "Die":
        return reason.defect;
      case "Interrupt":
        return reason.fiberId;
    }
  }
};
```

**Reason guards (v4)**

```ts
// Check reason types
Cause.isFailReason(reason);
Cause.isDieReason(reason);
Cause.isInterruptReason(reason);
```

**Cause-level predicates (v4)**

```ts
Cause.hasFails(cause); // has any Fail reasons
Cause.hasDies(cause); // has any Die reasons
Cause.hasInterrupts(cause); // has any Interrupt reasons
Cause.hasInterruptsOnly(cause); // only Interrupt reasons
Cause.isEmpty(cause); // no reasons
```

**Extractors (v4)**

```ts
// Find specific reason types
Cause.findErrorOption(cause); // Option<E>
Cause.findError(cause); // Result<E>
Cause.findDefect(cause); // Result<unknown>
Cause.findInterrupt(cause); // Result<FiberId>

// Filter reasons
cause.reasons.filter(Cause.isFailReason);
cause.reasons.filter(Cause.isDieReason);

// Get all of specific type
Cause.failures(cause); // all Fail reasons
cause.reasons.filter(Cause.isDieReason); // all Die reasons
```

**Display**

```ts
Cause.pretty(cause);
```

## Exit

**Effect completion result**

```ts
import { Exit } from "effect";

// Get from effect
const exit = yield* Effect.exit(effect);

// Check
if (Exit.isSuccess(exit)) {
  console.log(exit.value);
} else if (Exit.isFailure(exit)) {
  // v4: exit.cause.reasons for flattened structure
  console.log(Cause.pretty(exit.cause));
}

// Match
Exit.match(exit, {
  onFailure: (cause) => /* ... */,
  onSuccess: (value) => /* ... */
});

// Create
Exit.succeed(value);
Exit.fail(error);
Exit.die(defect);
Exit.interrupt(fiberId);
```

## Duration

**Time spans**

```ts
import { Duration } from "effect";

// Create
Duration.millis(100);
Duration.seconds(5);
Duration.minutes(2);
Duration.hours(1);

// Decode from string
Duration.decode("100 millis");
Duration.decode("5 seconds");
Duration.decode("2 minutes");

// Operations
Duration.sum(d1, d2);
Duration.times(duration, 3);
Duration.lessThan(d1, d2);

// Convert
Duration.toMillis(duration);
Duration.toSeconds(duration);
```

## Stream

**Lazy, effectful sequences**

```ts
import { Stream } from "effect";

// Create
Stream.make(1, 2, 3);
Stream.fromIterable([1, 2, 3]);
Stream.range(0, 10);
Stream.repeatValue(42);

// From Effect
Stream.fromEffect(effect);
Stream.unfold(0, (n) => Option.some([n, n + 1]));

// Transform
Stream.map(stream, (n) => n * 2);
Stream.filter(stream, (n) => n > 5);
Stream.flatMap(stream, (n) => Stream.range(0, n));
Stream.take(stream, 10);
Stream.drop(stream, 5);

// Combine
Stream.concat(s1, s2);
Stream.merge(s1, s2);
Stream.zip(s1, s2);

// Consume
Stream.runCollect(stream); // Chunk<A>
Stream.runForEach(stream, (item) => Console.log(item));
Stream.runFold(stream, 0, (acc, n) => acc + n);
```

## Data

**Value equality helpers**

```ts
import { Data } from "effect";

// Struct with value equality
const user = Data.struct({
  id: 1,
  name: "Alice",
});

// Tagged (discriminated unions)
const ok = Data.tagged("Ok", { value: 42 });
const err = Data.tagged("Err", { error: "failed" });

// Tagged errors
class NotFoundError extends Data.TaggedError("NotFound")<{
  id: string;
}> {}

class ValidationError extends Data.TaggedError("Validation")<{
  field: string;
  message: string;
}> {}

// Case class
class User extends Data.Class<{
  id: number;
  name: string;
}> {}

const user1 = new User({ id: 1, name: "Alice" });
const user2 = new User({ id: 1, name: "Alice" });
console.log(user1 === user2); // false
console.log(Equal.equals(user1, user2)); // true
```

## Redacted

**Hide sensitive values in logs**

```ts
import { Redacted } from "effect";

// Create
const secret = Redacted.make("my-secret-key");

// Hides in logs
console.log(secret); // <redacted>

// Access value
const value = Redacted.value(secret); // "my-secret-key"
```

## Match

**Pattern matching**

```ts
import { Match } from "effect";

const result = Match.value(input).pipe(
  Match.when({ _tag: "Success" }, ({ value }) => `Success: ${value}`),
  Match.when({ _tag: "Error" }, ({ error }) => `Error: ${error}`),
  Match.orElse(() => "Unknown"),
);

// Type-safe exhaustive matching
Match.type<User | Admin | Guest>().pipe(
  Match.tag("User", (user) => user.name),
  Match.tag("Admin", (admin) => `Admin: ${admin.name}`),
  Match.tag("Guest", () => "Guest"),
  Match.exhaustive,
);
```

## Queue

**FIFO async coordination**

```ts
import { Queue } from "effect";

const queue = yield * Queue.bounded<number>(100);

// Producer
yield * Queue.offer(queue, 42);
yield * Queue.offerAll(queue, [1, 2, 3]);

// Consumer
const item = yield * Queue.take(queue);
const batch = yield * Queue.takeUpTo(queue, 10);

// Check
const size = yield * Queue.size(queue);
const isFull = yield * Queue.isFull(queue);

// Shutdown
yield * Queue.shutdown(queue);
```

## Deferred

**One-time async variable**

**Important v4 change:** Deferred is no longer yieldable. Use `Deferred.await`:

```ts
import { Deferred } from "effect";

const deferred = yield * Deferred.make<string, Error>();

// Set value (only once)
yield * Deferred.succeed(deferred, "value");

// Or fail
yield * Deferred.fail(deferred, new Error("failed"));

// Await result (v4: use explicit method)
const value = yield * Deferred.await(deferred);

// Poll (non-blocking)
const opt = yield * Deferred.poll(deferred);
```

## Ref

**Mutable reference**

**Important v4 change:** Ref is no longer yieldable. Use `Ref.get`, `Ref.set`, etc.:

```ts
import { Ref } from "effect";

const counter = yield * Ref.make(0);

// Get (v4: use explicit method)
const value = yield * Ref.get(counter);

// Set
yield * Ref.set(counter, 42);

// Update atomically
yield * Ref.update(counter, (n) => n + 1);

// Modify (get old + update)
const prev = yield * Ref.modify(counter, (n) => [n, n + 1]);
```

## Equality (v4: Structural by Default)

In v4, `Equal.equals` uses structural equality by default:

```ts
import { Equal } from "effect";

// v4: Structural equality by default
Equal.equals({ a: 1 }, { a: 1 }); // true
Equal.equals([1, 2], [1, 2]); // true
Equal.equals(new Map([["a", 1]]), new Map([["a", 1]])); // true

// NaN equality
Equal.equals(NaN, NaN); // true

// Opt out: reference equality
const obj = Equal.byReference({ a: 1 });
Equal.equals(obj, { a: 1 }); // false

// Equivalence (renamed in v4)
Equal.asEquivalence<number>(); // v4: was equivalence()
```

## Best Practices

Use Option for nullable values
Use Result (Either) for explicit error handling
Use Chunk for immutable arrays
Use HashSet/HashMap for value equality
Use Stream for large/infinite sequences
Use Data.TaggedError for domain errors

Avoid:

- Using null/undefined (use Option)
- Mutating Chunk/HashSet/HashMap
- Using Array methods on Chunk directly
- Ignoring Stream backpressure
