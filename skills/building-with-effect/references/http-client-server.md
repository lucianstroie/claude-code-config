# HTTP Client & Server — Quick Start & Index

Building HTTP clients and servers with Effect.

See related examples in [effect-smol/ai-docs/src/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/)

## Table of Contents

- [Quick Start](#quick-start)
- [Topic Index](#topic-index)
- [See Also](#see-also)

## Quick Start

Define an API with `HttpApi.make`, add groups with `HttpApiGroup.make`, and add endpoints with `HttpApiEndpoint.get/post/delete/patch`:

```ts
import { NodeHttpServer, NodeRuntime } from "@effect/platform-node"
import { Effect, Layer, Schema } from "effect"
import { HttpRouter } from "effect/unstable/http"
import { HttpApi, HttpApiBuilder, HttpApiEndpoint, HttpApiGroup } from "effect/unstable/httpapi"
import { createServer } from "node:http"

const User = Schema.Struct({
  id: Schema.Int,
  name: Schema.String
})

// Define API using fluent chain pattern
const Api = HttpApi.make("MyApi").add(
  HttpApiGroup.make("Users").add(
    HttpApiEndpoint.get("getUsers", "/users", {
      success: Schema.Array(User)
    }),
    HttpApiEndpoint.get("getUser", "/user/:id", {
      params: { id: Schema.Int },
      success: User
    }),
    HttpApiEndpoint.post("createUser", "/users", {
      payload: User,
      success: User
    })
  )
)

// Implement handlers
const UsersLive = HttpApiBuilder.group(
  Api,
  "Users",
  (handlers) =>
    handlers
      .handle("getUsers", () =>
        Effect.succeed([{ id: 1, name: "User 1" }])
      )
      .handle("getUser", (ctx) =>
        Effect.succeed({ id: ctx.params.id, name: `User ${ctx.params.id}` })
      )
      .handle("createUser", (ctx) =>
        Effect.succeed(ctx.payload)
      )
)

// Server
const ApiLive = HttpApiBuilder.layer(Api).pipe(
  Layer.provide(UsersLive),
  HttpRouter.serve,
  Layer.provide(NodeHttpServer.layer(createServer, { port: 3000 }))
)

Layer.launch(ApiLive).pipe(NodeRuntime.runMain)
```

## Topic Index

| Topic | File |
|-------|------|
| API definition, routing, endpoints, params, prefixing | [http-api.md](http-api.md) |
| Query params, headers, multipart, request encoding | [http-request.md](http-request.md) |
| Status codes, response encoding, headers, cookies, redirects, streaming | [http-response.md](http-response.md) |
| Custom errors, predefined HttpApiError types | [http-errors.md](http-errors.md) |
| Middleware, security schemes | [http-security.md](http-security.md) |
| OpenAPI annotations, top-level groups | [http-openapi.md](http-openapi.md) |
| Generated clients, web handler | [http-client.md](http-client.md) |

## See Also

- [migration.md](migration.md) - package migration notes