# Schedules

Working with Effect Schedules for retries, repeats, and polling.

See related examples in [effect-smol/ai-docs/src/06_schedule/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/06_schedule/)

## Overview

Schedules define recurring patterns for:

- Retrying failed operations
- Repeating successful operations
- Polling data sources
- Throttling and rate limiting

## Schedule Constructors

### Basic Schedules

```ts
import { Schedule } from "effect";

// Fixed number of recurrences
const maxRetries = Schedule.recurs(5);

// Spaced intervals
const spacedPolling = Schedule.spaced("30 seconds");

// Exponential backoff
const exponentialBackoff = Schedule.exponential("200 millis");

// Fibonacci backoff
const fibonacciBackoff = Schedule.fibonacci("100 millis");
```

### Advanced Schedules

```ts
// Fixed delay between executions
const fixedDelay = Schedule.fixed("1 second");

// Cron-like schedule
const cronSchedule = Schedule.cron("0 0 * * *"); // Daily at midnight

// Windowed schedule
const windowed = Schedule.windowed("1 minute");
```

## Using Schedules

### Retry with Schedule

```ts
import { Effect, Random, Schedule, Schema } from "effect";

class HttpError extends Schema.TaggedErrorClass<HttpError>()("HttpError", {
  message: Schema.String,
  status: Schema.Number,
  retryable: Schema.Boolean,
}) {}

const fetchUserProfile = Effect.fn("fetchUserProfile")(function* (
  userId: string,
) {
  const random = yield* Random.next;
  const status = random > 0.7 ? 200 : random > 0.3 ? 503 : 401;

  if (status !== 200) {
    return yield* new HttpError({
      message: `Request for ${userId} failed`,
      status,
      retryable: status >= 500,
    });
  }

  return { id: userId, name: "Ada Lovelace" } as const;
});

// Simple retry
const withRetry = fetchUserProfile("user-123").pipe(
  Effect.retry({ times: 3 }),
  Effect.orDie, // Fail after exhausting retries
);

// Retry with schedule
const withSchedule = fetchUserProfile("user-123").pipe(
  Effect.retry(Schedule.exponential("100 millis")),
  Effect.orDie,
);
```

### Schedule Composition

```ts
// Both schedules must continue
const retryBackoffWithLimit = Schedule.both(
  Schedule.exponential("250 millis"),
  Schedule.recurs(6),
);
// Exponential backoff up to 6 attempts

// Either schedule can continue
const keepTryingUntilBothStop = Schedule.either(
  Schedule.spaced("2 seconds"),
  Schedule.recurs(3),
);
// Retry every 2 seconds OR up to 3 times (whichever comes first)
```

### Conditional Retry

```ts
// Retry only for retryable errors
const retryableOnly = Schedule.exponential("200 millis").pipe(
  Schedule.setInputType<HttpError>(),
  Schedule.while(({ input }) => input.retryable),
);

const loadUserWithRetry = fetchUserProfile("user-123").pipe(
  Effect.retry(retryableOnly),
  Effect.orDie,
);
```

### Instrumented Schedules

```ts
const instrumentedRetry = retryableOnly.pipe(
  Schedule.setInputType<HttpError>(),
  Schedule.tapInput((error) =>
    Effect.logDebug(`Retrying after ${error.status}: ${error.message}`),
  ),
  Schedule.tapOutput((delay) => Effect.logDebug(`Next retry in ${delay}ms`)),
);
```

## Production Patterns

### Capped Exponential Backoff with Jitter

```ts
const productionRetrySchedule = Schedule.exponential("250 millis").pipe(
  // Cap delay at 10 seconds
  Schedule.either(Schedule.spaced("10 seconds")),
  // Add jitter to avoid thundering herd
  Schedule.jittered,
  // Only retry retryable errors
  Schedule.setInputType<HttpError>(),
  Schedule.while(({ input }) => input.retryable),
);

const loadUserWithProductionRetry = fetchUserProfile("user-123").pipe(
  Effect.retry(productionRetrySchedule),
  Effect.orDie,
);
```

### Retry with Inferred Input

```ts
const loadUserWithInferredInput = fetchUserProfile("user-123").pipe(
  Effect.retry(($) =>
    $(Schedule.spaced("1 second")).pipe(
      Schedule.while(({ input }) => input.retryable),
    ),
  ),
  Effect.orDie,
);
```

## Schedule Transformations

### Map Output

```ts
const mapped = Schedule.spaced("1 second").pipe(
  Schedule.map((delay) => delay * 2),
);
```

### Filter

```ts
const filtered = Schedule.spaced("1 second").pipe(
  Schedule.filter((delay) => delay < 10000),
);
```

### Until/While

```ts
// Continue while condition is true
const whileSchedule = Schedule.spaced("1 second").pipe(
  Schedule.while((output) => output.attempt < 5),
);

// Continue until condition is true
const untilSchedule = Schedule.spaced("1 second").pipe(
  Schedule.until((output) => output.success),
);
```

### Delay Modifications

```ts
// Add random jitter
const jittered = Schedule.exponential("100 millis").pipe(Schedule.jittered);

// Add fixed delay
const delayed = Schedule.spaced("1 second").pipe(
  Schedule.delayed((delay) => delay + 1000),
);
```

## Repeating Operations

### Repeat with Schedule

```ts
const pollForUpdates = Effect.gen(function* () {
  yield* Effect.logInfo("Checking for updates...");
  return yield* checkForUpdates();
}).pipe(Effect.repeat(Schedule.spaced("5 seconds")));
```

### Repeat with Condition

```ts
const pollUntilComplete = checkStatus.pipe(
  Effect.repeat({
    schedule: Schedule.spaced("1 second"),
    until: (status) => status === "complete",
  }),
);
```

## Combining Schedules

### Sequential Schedules

```ts
// First 3 attempts: 100ms delay
// Next 3 attempts: 1s delay
// Then: 5s delay
const sequential = Schedule.sequential([
  Schedule.exponential("100 millis").pipe(Schedule.recurs(3)),
  Schedule.spaced("1 second").pipe(Schedule.recurs(3)),
  Schedule.spaced("5 seconds"),
]);
```

### Intersect Schedules

```ts
// Both conditions must be met
const intersection = Schedule.intersect(
  Schedule.recurs(10), // Max 10 attempts
  Schedule.exponential("100 millis"), // Exponential backoff
);
```

## Schedule with Effects

### Schedule with Initial Delay

```ts
const delayedStart = Effect.sleep("5 seconds").pipe(
  Effect.andThen(operation),
  Effect.retry(Schedule.spaced("1 second")),
);
```

### Schedule with Timeout

```ts
const withTimeout = operation.pipe(
  Effect.timeout("30 seconds"),
  Effect.retry(Schedule.spaced("5 seconds")),
);
```

## Testing Schedules

```ts
import { TestClock } from "effect/testing";

const test = Effect.gen(function* () {
  const fiber = yield* Effect.fork(
    operation.pipe(Effect.retry(Schedule.spaced("1 second"))),
  );

  // Advance time to trigger retries
  yield* TestClock.adjust("5 seconds");

  const result = yield* Fiber.join(fiber);
});
```

## Common Use Cases

### API Polling

```ts
const pollApi = Effect.fn("pollApi")(
  function* (endpoint: string) {
    const response = yield* httpClient.get(endpoint);

    if (response.status === 202) {
      return yield* new PendingError();
    }

    return response.data;
  },
  Effect.retry({
    schedule: Schedule.exponential("1 second"),
    while: (error) => error._tag === "PendingError",
    times: 30, // Max 30 attempts
  }),
);
```

### Health Checks

```ts
const healthCheck = Effect.gen(function* () {
  yield* pingService();
  yield* Effect.logInfo("Service is healthy");
}).pipe(Effect.repeat(Schedule.spaced("30 seconds")));
```

### Cache Refresh

```ts
const refreshCache = Effect.gen(function* () {
  const data = yield* fetchFreshData();
  yield* updateCache(data);
}).pipe(Effect.repeat(Schedule.spaced("5 minutes")));
```

### Circuit Breaker Pattern

```ts
const withCircuitBreaker = operation.pipe(
  Effect.retry({
    schedule: Schedule.exponential("100 millis"),
    times: 3,
    // On repeated failures, open circuit
    onFailure: (error) =>
      Effect.sync(() => {
        consecutiveFailures++;
        if (consecutiveFailures > 5) {
          circuitOpen = true;
        }
      }),
  }),
);
```

## Best Practices

1. **Use exponential backoff** for transient failures to avoid overwhelming services
2. **Cap maximum delay** to prevent excessive wait times
3. **Add jitter** to prevent thundering herd problems
4. **Filter non-retryable errors** to fail fast
5. **Set maximum attempts** to prevent infinite retries
6. **Log retry attempts** for observability
7. **Use `orDie` after retries** to convert to defects if recovery fails

## Quick Reference

```ts
// Basic schedules
Schedule.recurs(5); // 5 attempts
Schedule.spaced("1 second"); // 1 second between attempts
Schedule.exponential("100 millis"); // Exponential backoff
Schedule.fibonacci("100 millis"); // Fibonacci backoff

// Composition
Schedule.both(s1, s2); // Both must continue
Schedule.either(s1, s2); // Either can continue
Schedule.sequential([s1, s2, s3]); // Run in sequence

// Transformation
schedule.pipe(
  Schedule.jittered, // Add random jitter
  Schedule.recurs(10), // Limit to 10 attempts
  Schedule.while((output) => condition), // Continue while condition
);

// Usage
effect.pipe(Effect.retry(schedule), Effect.orDie);
```
