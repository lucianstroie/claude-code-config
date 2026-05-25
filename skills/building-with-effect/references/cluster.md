# Cluster

Building distributed applications with Effect Cluster.

See related examples in [effect-smol/ai-docs/src/80_cluster/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/80_cluster/)

## Overview

Effect Cluster provides:

- Distributed entity management
- RPC-based communication between nodes
- Automatic entity lifecycle management
- In-memory and persistent storage options

## Setup

```ts
import { NodeClusterSocket, NodeRuntime } from "@effect/platform-node";
import { Effect, Layer, Ref, Schema } from "effect";
import { ClusterSchema, Entity, TestRunner } from "effect/unstable/cluster";
import { Rpc } from "effect/unstable/rpc";
import type { SqlClient } from "effect/unstable/sql";
```

## Defining Entities

### Entity RPCs

```ts
// Define RPC operations
export const Increment = Rpc.make("Increment", {
  payload: { amount: Schema.Number },
  success: Schema.Number,
});

export const GetCount = Rpc.make("GetCount", {
  success: Schema.Number,
}).pipe(
  // Mark as persisted for durable storage
  Rpc.annotate(ClusterSchema.Persisted, true),
);

// Create entity from RPCs
export const Counter = Entity.make("Counter", [Increment, GetCount]);
```

### Entity Implementation

```ts
// Entity handlers with in-memory state
export const CounterEntityLayer = Counter.toLayer(
  Effect.gen(function* () {
    const count = yield* Ref.make(0);

    return Counter.of({
      Increment: ({ payload }) =>
        Ref.updateAndGet(count, (current) => current + payload.amount),

      GetCount: () =>
        Ref.get(count).pipe(
          // Allow concurrent reads
          Rpc.fork,
        ),
    });
  }),
  { maxIdleTime: "5 minutes" }, // Passivate after 5 min idle
);
```

## Running Cluster

### Production Cluster

```ts
// Create cluster layer
const ClusterLayer = NodeClusterSocket.layer().pipe(
  Layer.provide(SqlClientLayer), // For persistence
);

// Merge all entity layers
const EntitiesLayer = Layer.mergeAll(CounterEntityLayer);

const ProductionLayer = EntitiesLayer.pipe(Layer.provide(ClusterLayer));

// Run
Layer.launch(ProductionLayer).pipe(NodeRuntime.runMain);
```

### Test Cluster (Single Node)

```ts
// Use TestRunner for local testing
const ClusterLayerTest = TestRunner.layer;

const TestLayer = EntitiesLayer.pipe(Layer.provideMerge(ClusterLayerTest));
```

## Using Entities

### Client Access

```ts
const useCounter = Effect.gen(function* () {
  // Get client factory
  const clientFor = yield* Counter.client;

  // Create client for specific entity
  const counter = clientFor("counter-123");

  // Call RPCs
  const afterIncrement = yield* counter.Increment({ amount: 1 });
  const currentCount = yield* counter.GetCount();

  console.log(
    `Count after increment: ${afterIncrement}, current: ${currentCount}`,
  );
});
```

### Entity Lifecycle

```ts
// Entities are created on first access
// After maxIdleTime of inactivity, they are passivated
// Next access recreates the entity (state is lost unless persisted)
```

## Persistence

### Persisted RPCs

```ts
// Only persisted RPCs survive entity restart
const PersistedGetCount = Rpc.make("GetCount", {
  success: Schema.Number,
}).pipe(Rpc.annotate(ClusterSchema.Persisted, true));

// Non-persisted RPCs don't save state
const VolatileIncrement = Rpc.make("Increment", {
  payload: { amount: Schema.Number },
  success: Schema.Number,
});
// Not persisted - counter resets on passivation
```

## Best Practices

1. **Use Rpc.fork** for read-only operations to allow concurrency
2. **Persist critical state** with `ClusterSchema.Persisted`
3. **Set appropriate maxIdleTime** based on usage patterns
4. **Use TestRunner** for local development
5. **Monitor entity passivation** in production
6. **Keep entity logic simple** - complex logic belongs in services
7. **Use unique entity IDs** - collisions cause issues

## Common Patterns

### Distributed Counter

```ts
// Each counter is an entity identified by ID
const incrementCounter = (id: string, amount: number) =>
  Effect.gen(function* () {
    const clientFor = yield* Counter.client;
    const counter = clientFor(id);
    return yield* counter.Increment({ amount });
  });
```

### Session Management

```ts
const UserSession = Entity.make("UserSession", [
  Rpc.make("GetData", { success: Schema.Unknown }),
  Rpc.make("SetData", {
    payload: { key: Schema.String, value: Schema.Unknown },
    success: Schema.Void,
  }),
]);
```

### Rate Limiter

```ts
const RateLimiter = Entity.make("RateLimiter", [
  Rpc.make("Acquire", {
    payload: { permits: Schema.Number },
    success: Schema.Boolean,
  }),
]);
```

## Testing

```ts
describe("Counter", () => {
  it.effect("increments", () =>
    Effect.gen(function* () {
      const clientFor = yield* Counter.client;
      const counter = clientFor("test-1");

      const result1 = yield* counter.Increment({ amount: 5 });
      assert.strictEqual(result1, 5);

      const result2 = yield* counter.Increment({ amount: 3 });
      assert.strictEqual(result2, 8);
    }).pipe(Effect.provide(TestLayer)),
  );
});
```
