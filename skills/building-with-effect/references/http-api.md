# HTTP API — Definition & Routing

## Building Blocks

The `HttpApi` modules let you describe your HTTP API once and use that description to run a server, generate documentation, and create a type-safe client.

Three building blocks:

- **HttpApi** — the top-level object that combines groups into a complete API
- **HttpApiGroup** — a collection of related endpoints (e.g., all user-related routes)
- **HttpApiEndpoint** — a single route (path + HTTP method) with schemas for request and response

```
HttpApi
├── HttpGroup
│   ├── HttpEndpoint
│   └── HttpEndpoint
└── HttpGroup
    ├── HttpEndpoint
```

## Defining an API

Use the fluent chain pattern with `HttpApi.make().add()`:

```ts
import { HttpApi, HttpApiEndpoint, HttpApiGroup } from "effect/unstable/httpapi"
import { Schema } from "effect"

const User = Schema.Struct({
  id: Schema.Int,
  name: Schema.String
})

const Api = HttpApi.make("MyApi").add(
  HttpApiGroup.make("Users").add(
    HttpApiEndpoint.get("getUsers", "/users", {
      success: Schema.Array(User)
    })
  )
)
```

## Routing

### GET

Use `HttpApiEndpoint.get` to retrieve data:

```ts
HttpApiEndpoint.get("getUsers", "/users", {
  success: Schema.Array(User)
})
```

### POST

Use `HttpApiEndpoint.post` to create resources:

```ts
HttpApiEndpoint.post("createUser", "/users", {
  payload: User,
  success: User
})
```

### DELETE

Use `HttpApiEndpoint.delete` to remove resources:

```ts
HttpApiEndpoint.delete("deleteUser", "/user/:id", {
  params: { id: Schema.Int }
})
```

### PATCH

Use `HttpApiEndpoint.patch` for partial updates:

```ts
HttpApiEndpoint.patch("updateUser", "/user/:id", {
  params: { id: Schema.Int },
  payload: Schema.Struct({ name: Schema.String }),
  success: User
})
```

## Path Parameters

Capture dynamic URL segments with `params`:

```ts
HttpApiEndpoint.get("getUser", "/user/:id", {
  params: {
    id: Schema.Int
  },
  success: User
})

// Handler accesses via ctx.params
handlers.handle("getUser", (ctx) => {
  const id = ctx.params.id
  return Effect.succeed({ id, name: `User ${id}` })
})
```

## Catch-All Endpoints

Path `"*"` matches any URL not handled by other endpoints. Must be last in the group:

```ts
HttpApiEndpoint.get("catchAll", "*", {
  success: Schema.String
})

handlers.handle("catchAll", () =>
  Effect.succeed("Not found")
)
```

> [!IMPORTANT]
> The catch-all endpoint must be the last endpoint in the group.

## Prefixing

Add common path prefixes at endpoint, group, or API level:

```ts
// Endpoint-level prefix
HttpApiEndpoint.get("endpoint", "/a", { success: Schema.String })
  .prefix("/prefix")

// Group-level prefix
HttpApiGroup.make("group")
  .prefix("/groupPrefix")
  .add(
    HttpApiEndpoint.get("endpoint", "/b", { success: Schema.String })
  )

// API-level prefix
HttpApi.make("api")
  .prefix("/apiPrefix")
  .add(HttpApiGroup.make("group"))
```

## Handler Implementation

Handlers are implemented using `HttpApiBuilder.group`:

```ts
import { HttpApiBuilder } from "effect/unstable/httpapi"
import { Effect } from "effect"

const UsersLive = HttpApiBuilder.group(
  Api,
  "Users",
  (handlers) =>
    handlers
      .handle("getUsers", () =>
        Effect.succeed([{ id: 1, name: "User 1" }])
      )
      .handle("getUser", (ctx) => {
        const id = ctx.params.id
        return Effect.succeed({ id, name: `User ${id}` })
      })
)
```

The handler context provides:
- `ctx.params` — path parameters
- `ctx.query` — query parameters
- `ctx.payload` — request body
- `ctx.headers` — request headers
- `ctx.request` — raw `HttpServerRequest`