# PubSub

Event broadcasting and subscription with PubSub.

See full example: [PubSub Service](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/01_effect/06_pubsub/10_pubsub.ts)

## Overview

PubSub provides an in-process event bus for broadcasting messages to multiple subscribers. It's useful for:

- Domain event publishing
- Cross-service communication
- Real-time updates
- Decoupled architectures

## Creating a PubSub

### Bounded PubSub (with backpressure)

```ts
import { Effect, PubSub } from "effect";

const pubsub =
  yield *
  PubSub.bounded<OrderEvent>({
    capacity: 256, // Maximum events in buffer
    replay: 50, // Allow late subscribers to catch up on recent events
  });
```

### Unbounded PubSub

```ts
const pubsub = yield * PubSub.unbounded<OrderEvent>();
// No backpressure - use with caution
```

## Service Pattern with PubSub

```ts
import { Effect, Layer, PubSub, Context, Stream } from "effect";

export type OrderEvent =
  | { readonly _tag: "OrderPlaced"; readonly orderId: string }
  | { readonly _tag: "PaymentCaptured"; readonly orderId: string }
  | { readonly _tag: "OrderShipped"; readonly orderId: string };

export class OrderEvents extends Context.Service<
  OrderEvents,
  {
    publish(event: OrderEvent): Effect.Effect<void>;
    publishAll(events: ReadonlyArray<OrderEvent>): Effect.Effect<void>;
    readonly subscribe: Stream.Stream<OrderEvent>;
  }
>()("acme/OrderEvents") {
  static readonly layer = Layer.effect(
    OrderEvents,
    Effect.gen(function* () {
      // Create bounded PubSub with replay buffer
      const pubsub = yield* PubSub.bounded<OrderEvent>({
        capacity: 256,
        replay: 50, // Late subscribers catch up on 50 recent events
      });

      // Ensure cleanup when service is torn down
      yield* Effect.addFinalizer(() => PubSub.shutdown(pubsub));

      // Publish single event
      const publish = Effect.fn("OrderEvents.publish")(function* (
        event: OrderEvent,
      ) {
        yield* PubSub.publish(pubsub, event);
      });

      // Publish multiple events
      const publishAll = Effect.fn("OrderEvents.publishAll")(function* (
        events: ReadonlyArray<OrderEvent>,
      ) {
        yield* PubSub.publishAll(pubsub, events);
      });

      // Create stream from PubSub
      const subscribe = Stream.fromPubSub(pubsub);

      return OrderEvents.of({ publish, publishAll, subscribe });
    }),
  );
}
```

## Publishing Events

### Single Event

```ts
const program = Effect.gen(function* () {
  const events = yield* OrderEvents;

  yield* events.publish({
    _tag: "OrderPlaced",
    orderId: "ord_123",
  });
});
```

### Multiple Events

```ts
const program = Effect.gen(function* () {
  const events = yield* OrderEvents;

  yield* events.publishAll([
    { _tag: "OrderPlaced", orderId: "ord_123" },
    { _tag: "PaymentCaptured", orderId: "ord_123" },
    { _tag: "OrderShipped", orderId: "ord_123" },
  ]);
});
```

## Subscribing to Events

### Basic Subscription

```ts
const subscriber = Effect.gen(function* () {
  const events = yield* OrderEvents;

  yield* events.subscribe.pipe(
    Stream.runForEach((event) =>
      Effect.logInfo(`Received: ${event._tag} for ${event.orderId}`),
    ),
  );
});
```

### Filtered Subscription

```ts
const paymentSubscriber = Effect.gen(function* () {
  const events = yield* OrderEvents;

  yield* events.subscribe.pipe(
    Stream.filter((event) => event._tag === "PaymentCaptured"),
    Stream.runForEach((event) =>
      Effect.gen(function* () {
        yield* Effect.logInfo(`Processing payment for ${event.orderId}`);
        yield* sendReceiptEmail(event.orderId);
      }),
    ),
  );
});
```

### Multiple Subscribers

```ts
const analyticsSubscriber = Effect.gen(function* () {
  const events = yield* OrderEvents;

  yield* events.subscribe.pipe(
    Stream.runForEach((event) => recordAnalyticsMetric(event._tag, 1)),
  );
});

const loggingSubscriber = Effect.gen(function* () {
  const events = yield* OrderEvents;

  yield* events.subscribe.pipe(
    Stream.runForEach((event) => Effect.logDebug(`Event: ${event._tag}`)),
  );
});

// Both subscribers receive all events
const program = Effect.gen(function* () {
  yield* Effect.forkScoped(analyticsSubscriber);
  yield* Effect.forkScoped(loggingSubscriber);
});
```

## Advanced Patterns

### Replay Buffer

Replay buffers allow late subscribers to catch up on recent events:

```ts
const pubsub =
  yield *
  PubSub.bounded<OrderEvent>({
    capacity: 256,
    replay: 50, // Keep last 50 events for late subscribers
  });

// Subscriber joining late will receive the 50 most recent events first
const lateSubscriber = Effect.gen(function* () {
  yield* Effect.sleep("1 minute"); // Join late
  const events = yield* OrderEvents;

  yield* events.subscribe.pipe(
    Stream.take(10),
    Stream.runCollect,
    // Will receive 10 most recent events that occurred before subscription
  );
});
```

### Selective Publishing

```ts
const program = Effect.gen(function* () {
  const events = yield* OrderEvents;

  // Only publish if condition met
  const shouldNotify = yield* checkNotificationPreference();

  if (shouldNotify) {
    yield* events.publish({
      _tag: "OrderPlaced",
      orderId: "ord_123",
    });
  }
});
```

### PubSub with Transformation

```ts
const transformedSubscriber = Effect.gen(function* () {
  const events = yield* OrderEvents;

  yield* events.subscribe.pipe(
    Stream.map((event) => ({
      type: event._tag,
      id: event.orderId,
      timestamp: Date.now(),
    })),
    Stream.runForEach((transformed) => sendToExternalQueue(transformed)),
  );
});
```

## Best Practices

1. **Use bounded PubSub** with appropriate capacity for backpressure
2. **Add replay buffers** when late subscribers need to catch up
3. **Always add finalizers** to shut down PubSub on service teardown
4. **Fork subscribers** with `forkScoped` for concurrent processing
5. **Filter early** in stream pipelines to reduce processing
6. **Use tagged unions** for event types to enable pattern matching

## Integration with Services

```ts
import { Effect, Layer, Context } from "effect";

class OrderService extends Context.Service<
  OrderService,
  {
    createOrder(data: CreateOrderData): Effect.Effect<Order>;
  }
>()("app/OrderService") {
  static readonly layer = Layer.effect(
    OrderService,
    Effect.gen(function* () {
      const events = yield* OrderEvents;

      const createOrder = Effect.fn("OrderService.createOrder")(function* (
        data: CreateOrderData,
      ) {
        const order = yield* saveToDatabase(data);

        // Publish event after successful save
        yield* events.publish({
          _tag: "OrderPlaced",
          orderId: order.id,
        });

        return order;
      });

      return OrderService.of({ createOrder });
    }),
  ).pipe(Layer.provide(OrderEvents.layer));
}
```

## Testing with PubSub

```ts
import { assert, describe, it } from "@effect/vitest";
import { Effect, Chunk } from "effect";

describe("OrderEvents", () => {
  it.effect("publishes and receives events", () =>
    Effect.gen(function* () {
      const events = yield* OrderEvents;
      const received: OrderEvent[] = [];

      // Subscribe
      yield* Effect.fork(
        events.subscribe.pipe(
          Stream.take(1),
          Stream.runForEach((event) => Effect.sync(() => received.push(event))),
        ),
      );

      // Publish
      yield* events.publish({
        _tag: "OrderPlaced",
        orderId: "ord_123",
      });

      // Wait for processing
      yield* Effect.sleep("100 millis");

      assert.strictEqual(received.length, 1);
      assert.strictEqual(received[0]._tag, "OrderPlaced");
    }).pipe(Effect.provide(OrderEvents.layer)),
  );
});
```

## Common Use Cases

### Event Sourcing

```ts
const eventSourcingService = Effect.gen(function* () {
  const events = yield* OrderEvents;

  // Rebuild state from event stream
  const currentState = yield* events.subscribe.pipe(
    Stream.runFold(initialState, (state, event) => applyEvent(state, event)),
  );
});
```

### Cross-Module Communication

```ts
// Module A
const moduleA = Effect.gen(function* () {
  const events = yield* OrderEvents;
  yield* events.publish({ _tag: "OrderPlaced", orderId: "123" });
});

// Module B (in different file/service)
const moduleB = Effect.gen(function* () {
  const events = yield* OrderEvents;
  yield* events.subscribe.pipe(
    Stream.filter((e) => e._tag === "OrderPlaced"),
    Stream.runForEach(sendNotification),
  );
});
```

## Migration from Other Patterns

### From Callbacks

**Before:**

```ts
const createOrder = (data: OrderData, onSuccess: (order: Order) => void) => {
  // ... save order
  onSuccess(order);
};
```

**After:**

```ts
const createOrder = Effect.fn("createOrder")(function* (data: OrderData) {
  const order = yield* saveOrder(data);
  yield* events.publish({ _tag: "OrderCreated", orderId: order.id });
  return order;
});
```

### From Event Emitters

**Before:**

```ts
const emitter = new EventEmitter();
emitter.on("order", handler);
emitter.emit("order", data);
```

**After:**

```ts
const pubsub = yield * PubSub.bounded<OrderEvent>({ capacity: 256 });
const subscribe = Stream.fromPubSub(pubsub);
yield * PubSub.publish(pubsub, data);
```
