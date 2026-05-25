# HTTP API — Client & Web Handler

## Generated Client

Create a typed client from your API definition using `HttpApiClient.make`:

```ts
import { HttpApiClient } from "effect/unstable/httpapi"
import { FetchHttpClient } from "effect/unstable/http"
import { Effect } from "effect"

const program = Effect.gen(function*() {
  const client = yield* HttpApiClient.make(Api, {
    baseUrl: "http://localhost:3000"
  })
  
  // Call endpoints via group
  const users = yield* client.Users.getUsers()
  
  // With path params
  const user = yield* client.Users.getUser({ params: { id: 1 } })
  
  // With payload (POST/PATCH)
  yield* client.Users.createUser({ payload: { name: "John" } })
  
  return users
})

Effect.runFork(program.pipe(Effect.provide(FetchHttpClient.layer)))
```

### Client Options

```ts
const client = yield* HttpApiClient.make(Api, {
  baseUrl: "http://localhost:3000",
  transformClient: (client) =>
    client.pipe(
      HttpClient.mapRequest(
        flow(HttpClientRequest.bearerToken("token"))
      ),
      HttpClient.retryTransient({
        schedule: Schedule.exponential(100),
        times: 3
      })
    )
})
```

## Top-Level Groups

Endpoints in `topLevel` groups are exposed as direct methods:

```ts
// API definition
HttpApiGroup.make("Users", { topLevel: true }).add(
  HttpApiEndpoint.get("getUsers", "/users", { success: Schema.Array(User) })
)

// Client: client.getUsers() directly, not client.Users.getUsers()
```

## Client Middleware

Transform client requests with `transformClient`:

```ts
import { HttpClient, HttpClientRequest, flow, Schedule } from "effect/unstable/http"

const client = yield* HttpApiClient.make(Api, {
  baseUrl: "http://localhost:3000",
  transformClient: (client) =>
    client.pipe(
      // Add bearer token to all requests
      HttpClient.mapRequest(
        flow(HttpClientRequest.bearerToken("my-token"))
      ),
      // Retry transient failures
      HttpClient.retryTransient({
        schedule: Schedule.exponential(100),
        times: 3
      })
    )
})
```

## Web Handler (Serverless)

Convert API to a standard web handler with `HttpRouter.toWebHandler`:

```ts
import { HttpRouter, HttpServer } from "effect/unstable/http"

const { dispose, handler } = HttpRouter.toWebHandler(
  Layer.mergeAll(ApiLive)
)

// Use with Node http server
http
  .createServer(async (req, res) => {
    const url = `http://${req.headers.host}${req.url}`
    const init: RequestInit = {
      method: req.method!
    }

    const response = await handler(new Request(url, init))

    res.writeHead(
      response.status,
      response.statusText,
      Object.fromEntries(response.headers.entries())
    )
    const responseBody = await response.arrayBuffer()
    res.end(Buffer.from(responseBody))
  })
  .listen(3000, () => {
    console.log("Server running at http://localhost:3000/")
  })
  .on("close", () => {
    dispose()
  })
```

The `dispose` function should be called when shutting down to clean up resources.

## Client with Middleware

When using security middleware, provide the middleware layer to the client:

```ts
import { HttpApiMiddleware } from "effect/unstable/httpapi"

const client = yield* HttpApiClient.make(Api, {
  baseUrl: "http://localhost:3000"
}).pipe(
  Effect.provide(AuthorizationClient) // your auth middleware
)
```

## Error Handling

Client errors are typed based on the endpoint's error schema:

```ts
const result = yield* Effect.either(
  client.Users.getUser({ params: { id: 999 } })
)

if (result._tag === "Left") {
  // result.left is the error type from error: [...]
  console.log("Failed:", result.left)
} else {
  console.log("Success:", result.right)
}
```