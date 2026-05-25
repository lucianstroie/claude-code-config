# Streams

Working with Effect Streams for pull-based sequences of values over time.

## Overview

Effect Streams represent effectful, pull-based sequences of values over time. They model:

- Finite or infinite data sources
- Effectful transformations
- Backpressure and flow control
- Resource-safe consumption

## Creating Streams

### From Iterables

```ts
import { Stream } from "effect";

// From array
const numbers = Stream.fromIterable([1, 2, 3, 4, 5]);

// From range
const range = Stream.range(1, 100);

// From effect schedule (polling)
const samples = Stream.fromEffectSchedule(
  Effect.succeed(3),
  Schedule.spaced("30 seconds"),
).pipe(
  Stream.take(3), // Limit to 3 samples
);
```

### From Effects

```ts
import { Effect, Stream } from "effect";
import * as Option from "effect/Option";

// Single value
const single = Stream.fromEffect(Effect.succeed(42));

// Paginated API
const fetchJobsPage = Stream.paginate(
  0, // Start with page 0
  Effect.fn(function* (page) {
    yield* Effect.sleep("50 millis");

    const results = Array.from(
      { length: 100 },
      (_, i) => `Job ${i + 1 + page * 100}`,
    );
    const nextPage = page < 10 ? Option.some(page + 1) : Option.none();

    return [results, nextPage] as const;
  }),
);
```

### From Async Sources

```ts
import { Effect, Stream, Schema } from "effect";

class LetterError extends Schema.TaggedErrorClass<LetterError>()(
  "LetterError",
  { cause: Schema.Defect },
) {}

// From async iterable
async function* asyncIterable() {
  yield "a";
  yield "b";
  yield "c";
}

const letters = Stream.fromAsyncIterable(
  asyncIterable(),
  (cause) => new LetterError({ cause }),
);

// From callback
const callbackStream = Stream.callback<PointerEvent>(
  Effect.fn(function* (queue) {
    function onEvent(event: PointerEvent) {
      Queue.offerUnsafe(queue, event);
    }

    yield* Effect.acquireRelease(
      Effect.sync(() => button.addEventListener("click", onEvent)),
      () => Effect.sync(() => button.removeEventListener("click", onEvent)),
    );
  }),
);

// From event listener (DOM)
const events = Stream.fromEventListener<PointerEvent>(button, "click");
```

### From Node.js Streams

```ts
import { NodeStream } from "@effect/platform-node";
import { Schema } from "effect";

class NodeStreamError extends Schema.TaggedErrorClass<NodeStreamError>()(
  "NodeStreamError",
  { cause: Schema.Defect },
) {}

const nodeStream = NodeStream.fromReadable({
  evaluate: () => Readable.from(["Hello", " ", "world", "!"]),
  onError: (cause) => new NodeStreamError({ cause }),
  closeOnDone: true,
});
```

## Transforming Streams

### Map and Filter

```ts
import { Effect, Stream } from "effect";

interface Order {
  readonly id: string;
  readonly subtotalCents: number;
  readonly shippingCents: number;
  readonly status: "paid" | "refunded";
}

// Map pure transformations
const normalizedOrders = orderEvents.pipe(
  Stream.map((order) => ({
    ...order,
    totalCents: order.subtotalCents + order.shippingCents,
  })),
);

// Filter
const paidOrders = normalizedOrders.pipe(
  Stream.filter((order) => order.status === "paid"),
);
```

### Effectful Transformations

```ts
// mapEffect for effectful transforms
const enrichedOrders = paidOrders.pipe(
  Stream.mapEffect(
    Effect.fn(function* (order) {
      yield* Effect.sleep("5 millis");
      const taxRate = 0.08;
      const taxCents = Math.round(order.totalCents * taxRate);

      return {
        ...order,
        taxCents,
        grandTotalCents: order.totalCents + taxCents,
      };
    }),
    { concurrency: 4 }, // Control parallelism
  ),
);
```

### FlatMap

```ts
// Flatten nested streams
const allOrders = Stream.make("US", "CA", "NZ").pipe(
  Stream.flatMap(
    (country) =>
      Stream.range(1, 50).pipe(
        Stream.map(
          (i): Order => ({
            id: `ord_${country}_${i}`,
            subtotalCents: Math.round(Math.random() * 100000),
            shippingCents: Math.round(Math.random() * 10000),
            status: i % 10 === 0 ? "refunded" : "paid",
          }),
        ),
      ),
    { concurrency: 2 }, // Control concurrency
  ),
);
```

## Consuming Streams

### Run Methods

```ts
import { Effect, Sink, Stream } from "effect";

// Collect all values into array
const collectedOrders = Stream.runCollect(enrichedOrders);

// Run for effects, ignore output
const drained = Stream.runDrain(enrichedOrders);

// Execute effect for each element
const logOrders = enrichedOrders.pipe(
  Stream.runForEach((order) =>
    Effect.logInfo(`Order ${order.id} total=$${order.grandTotalCents / 100}`),
  ),
);

// Fold to single value
const totalRevenue = enrichedOrders.pipe(
  Stream.runFold(0, (acc: number, order) => acc + order.grandTotalCents),
);

// Run with Sink
const totalViaSink = enrichedOrders.pipe(
  Stream.map((order) => order.grandTotalCents),
  Stream.run(Sink.sum),
);
```

### Edge Elements

```ts
// First element as Option
const firstLargeOrder = enrichedOrders.pipe(
  Stream.filter((order) => order.totalCents > 20000),
  Stream.runHead,
);

// Last element as Option
const lastLargeOrder = enrichedOrders.pipe(
  Stream.filter((order) => order.totalCents > 20000),
  Stream.runLast,
);
```

### Windowing

```ts
// Take first N
const firstTwo = enrichedOrders.pipe(Stream.take(2), Stream.runCollect);

// Skip first N
const afterWarmup = enrichedOrders.pipe(Stream.drop(1), Stream.runCollect);

// Take while condition
const untilLarge = enrichedOrders.pipe(
  Stream.takeWhile((order) => order.totalCents < 20000),
  Stream.runCollect,
);
```

## Encoding/Decoding

### NDJSON

```ts
import { DateTime, Schema, Stream } from "effect";
import { Ndjson } from "effect/unstable/encoding";

class LogEntry extends Schema.Class<LogEntry>("LogEntry")({
  timestamp: Schema.DateTimeUtcFromString,
  level: Schema.Literals(["info", "warn", "error"]),
  message: Schema.String,
}) {}

// Decode NDJSON strings to objects
const decodeUntyped = Stream.make(
  '{"timestamp":"2025-06-01T00:00:00Z","level":"info","message":"start"}\n' +
    '{"timestamp":"2025-06-01T00:00:01Z","level":"error","message":"oops"}\n',
).pipe(Stream.pipeThroughChannel(Ndjson.decodeString()), Stream.runCollect);

// Decode with schema validation
const decodeTyped = Stream.make(
  '{"timestamp":"2025-06-01T00:00:00Z","level":"info","message":"start"}\n',
).pipe(
  Stream.pipeThroughChannel(Ndjson.decodeSchemaString(LogEntry)()),
  Stream.runCollect,
);

// Encode objects to NDJSON
const encodeTyped = Stream.make(
  new LogEntry({
    timestamp: DateTime.make("2025-06-01T00:00:00Z"),
    level: "info",
    message: "start",
  }),
).pipe(
  Stream.pipeThroughChannel(Ndjson.encodeSchemaString(LogEntry)()),
  Stream.runCollect,
);
```

### MessagePack

```ts
import { Msgpack } from "effect/unstable/encoding";

// Similar API to NDJSON
const decodeMsgpack = Stream.pipeThroughChannel(Msgpack.decode());
const encodeMsgpack = Stream.pipeThroughChannel(Msgpack.encode());
```

## Error Handling

### Catch Stream Errors

```ts
const handleDecodeErrors = Stream.make("not-valid-json\n").pipe(
  Stream.pipeThroughChannel(Ndjson.decodeString()),
  Stream.catchTag("NdjsonError", (err) =>
    Stream.succeed({ recovered: true, kind: err.kind }),
  ),
  Stream.runCollect,
);
```

## Pipeline Example

```ts
// Complete pipeline: decode → transform → re-encode
const filterAndReencode = Stream.make(
  '{"timestamp":"2025-06-01T00:00:00Z","level":"info","message":"ok"}\n' +
    '{"timestamp":"2025-06-01T00:00:01Z","level":"error","message":"fail"}\n' +
    '{"timestamp":"2025-06-01T00:00:02Z","level":"warn","message":"slow"}\n',
).pipe(
  // Decode
  Stream.pipeThroughChannel(Ndjson.decodeSchemaString(LogEntry)()),
  // Filter
  Stream.filter((entry) => entry.level === "error"),
  // Re-encode
  Stream.pipeThroughChannel(Ndjson.encodeSchemaString(LogEntry)()),
  Stream.runCollect,
);
```

## External Examples

See full examples:
- [Creating Streams](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/02_stream/10_creating-streams.ts)
- [Consuming Streams](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/02_stream/20_consuming-streams.ts)
- [Encoding](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/02_stream/30_encoding.ts)

## Best Practices

1. **Use bounded buffers** to prevent memory issues with infinite streams
2. **Control concurrency** with `concurrency` parameter in `mapEffect` and `flatMap`
3. **Handle errors** with `Stream.catchTag` for recoverable errors
4. **Use resource safety** with `acquireRelease` for stream sources
5. **Add timeouts** for external data sources
6. **Filter early** to reduce processing overhead
7. **Use appropriate batch sizes** for batch operations

## Integration with PubSub

```ts
import { PubSub, Stream } from "effect";

const pubsub = yield * PubSub.bounded<OrderEvent>({ capacity: 256 });

// Create stream from PubSub
const orderStream = Stream.fromPubSub(pubsub);

// Process orders
yield *
  orderStream.pipe(
    Stream.filter((event) => event._tag === "OrderPlaced"),
    Stream.mapEffect(processOrder),
    Stream.runDrain,
  );
```

## Testing Streams

```ts
import { assert, describe, it } from "@effect/vitest";
import { Chunk, Effect, Stream } from "effect";

describe("Stream operations", () => {
  it.effect("maps and collects", () =>
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

## Common Patterns

### Rate Limiting

```ts
const rateLimited = fastStream.pipe(
  Stream.throttle({
    cost: () => 1,
    duration: "1 second",
    units: 10, // 10 items per second
  }),
);
```

### Buffering

```ts
const buffered = stream.pipe(
  Stream.buffer({ capacity: 100 }), // Buffer up to 100 items
);
```

### Debouncing

```ts
const debounced = eventStream.pipe(
  Stream.debounce("100 millis"), // Wait for 100ms of quiet
);
```

### Grouping

```ts
// Group by time windows
const windowed = stream.pipe(
  Stream.groupedWithin(100, "1 second"), // Groups of 100 or 1 second
);

// Group by key
const grouped = stream.pipe(Stream.groupByKey((event) => event.category));
```
