# Batching

Batching multiple requests into fewer external calls with RequestResolver.

See related examples in [effect-smol/ai-docs/src/05_batching/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/05_batching/)

## Overview

RequestResolver allows you to:
- Batch multiple requests into single external calls
- Deduplicate concurrent requests for the same data
- Cache results to avoid repeated lookups
- Maintain type safety across the batching boundary

## Basic Usage

### Define Request Type

```ts
import { Effect, Exit, Layer, Request, RequestResolver, Schema, Context } from "effect"

class User extends Schema.Class<User>("User")({
  id: Schema.Number,
  name: Schema.String,
  email: Schema.String
}) {}

class UserNotFound extends Schema.TaggedErrorClass<UserNotFound>()(
  "UserNotFound",
  { id: Schema.Number }
) {}
```

### Create Service with Batching

```ts
export class Users extends Context.Service<Users, {
  getUserById(id: number): Effect.Effect<User, UserNotFound>
}>()("app/Users") {
  static readonly layer = Layer.effect(
    Users,
    Effect.gen(function*() {
      // Define request class
      class GetUserById extends Request.Class<
        { readonly id: number },  // Request payload
        User,                     // Success type
        UserNotFound,             // Error type
        never                     // Requirements
      > {}
      
      // Simulate database
      const usersTable = new Map<number, User>([
        [1, new User({ id: 1, name: "Ada Lovelace", email: "ada@acme.dev" })],
        [2, new User({ id: 2, name: "Alan Turing", email: "alan@acme.dev" })],
        [3, new User({ id: 3, name: "Grace Hopper", email: "grace@acme.dev" })]
      ])
      
      // Create batching resolver
      const resolver = yield* RequestResolver.make<GetUserById>(
        Effect.fn(function*(entries) {
          // entries is array of requests to resolve
          for (const entry of entries) {
            const user = usersTable.get(entry.request.id)
            
            if (user) {
              // Complete with success
              entry.completeUnsafe(Exit.succeed(user))
            } else {
              // Complete with failure
              entry.completeUnsafe(
                Exit.fail(new UserNotFound({ id: entry.request.id }))
              )
            }
          }
        })
      ).pipe(
        // Wait 10ms to batch more requests
        RequestResolver.setDelay("10 millis"),
        // Add tracing
        RequestResolver.withSpan("Users.getUserById.resolver"),
        // Add LRU cache
        RequestResolver.withCache({ capacity: 1024 })
      )
      
      // Service method that uses batching
      const getUserById = (id: number) =>
        Effect.request(new GetUserById({ id }), resolver).pipe(
          Effect.withSpan("Users.getUserById", { attributes: { userId: id } })
        )
      
      return { getUserById } as const
    })
  )
}
```

### Using Batched Requests

```ts
// Run multiple lookups - automatically batched
export const batchedLookupExample = Effect.gen(function*() {
  const { getUserById } = yield* Users
  
  // These 5 calls will be batched into a single resolver execution
  // with unique IDs [1, 2, 3]
  yield* Effect.forEach([1, 2, 1, 3, 2], getUserById, {
    concurrency: "unbounded"
  })
})
```

## Advanced Patterns

### With Tracing

```ts
const resolver = yield* RequestResolver.make<GetUserById>(
  Effect.fn(function*(entries) {
    for (const entry of entries) {
      // Access span from request services
      const requestSpan = Context.getOption(
        entry.services,
        Tracer.ParentSpan
      )
      
      // Resolve request
      const user = usersTable.get(entry.request.id)
      entry.completeUnsafe(
        user 
          ? Exit.succeed(user) 
          : Exit.fail(new UserNotFound({ id: entry.request.id }))
      )
    }
  })
)
```

### With External API

```ts
const resolver = yield* RequestResolver.make<GetUserById>(
  Effect.fn(function*(entries) {
    // Extract all unique IDs
    const ids = [...new Set(entries.map((e) => e.request.id))]
    
    // Single API call for all requests
    const users = yield* fetchUsersBatch(ids)
    
    // Complete each request
    for (const entry of entries) {
      const user = users.find((u) => u.id === entry.request.id)
      entry.completeUnsafe(
        user
          ? Exit.succeed(user)
          : Exit.fail(new UserNotFound({ id: entry.request.id }))
      )
    }
  })
).pipe(
  RequestResolver.setDelay("50 millis"),  // Wait to batch more
  RequestResolver.withCache({ capacity: 1000 })
)
```

### Cache Configuration

```ts
const resolver = RequestResolver.make<GetUserById>(resolve).pipe(
  RequestResolver.withCache({
    capacity: 1024,           // Max cached entries
    timeToLive: "1 hour"    // TTL for cached entries
  })
)
```

## Best Practices

1. **Set appropriate delays** - Balance latency vs batching efficiency
2. **Use caching** for frequently accessed data
3. **Deduplicate in resolver** - Handle repeated IDs gracefully
4. **Add tracing** for observability
5. **Complete all requests** - Don't leave entries hanging
6. **Use concurrency** when calling batched methods
7. **Monitor batch sizes** - Adjust delay based on metrics

## Testing

```ts
describe("Users", () => {
  it.effect("batches requests", () =>
    Effect.gen(function*() {
      const { getUserById } = yield* Users
      let apiCalls = 0
      
      // Mock resolver to count calls
      const result = yield* Effect.forEach(
        [1, 2, 3, 1, 2, 3],  // Duplicates
        getUserById,
        { concurrency: "unbounded" }
      )
      
      // Should deduplicate and batch
      assert.strictEqual(result.length, 6)
      assert.strictEqual(apiCalls, 1)  // Single batch call
    })
  )
})
```
