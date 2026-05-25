# HTTP API — Request Handling

## Query Parameters

Query parameters are the `?key=value` pairs appended to a URL. Use `Schema.optionalKey()` for optional params:

```ts
HttpApiEndpoint.get("getUsers", "/users", {
  query: {
    page: Schema.optionalKey(Schema.Int.check(Schema.isGreaterThan(0))),
    sort: Schema.optionalKey(Schema.Literals(["id", "name"]))
  },
  success: Schema.Array(User)
})

handlers.handle("getUsers", (ctx) => {
  const { page, sort } = ctx.query
  console.log(`page: ${page}, sort: ${sort}`)
  return Effect.succeed([])
})
```

### Array Query Parameters

Single query params can carry multiple values (`?a=1&a=2`). Wrap in `Schema.Array`:

```ts
query: {
  a: Schema.optionalKey(Schema.Array(Schema.String))
}

// Request: ?a=1&a=2&a=3
// ctx.query.a = ["1", "2", "3"]
```

## Request Headers

> [!IMPORTANT]
> All headers are normalized to lowercase. Always use lowercase keys.

```ts
HttpApiEndpoint.get("getUsers", "/users", {
  headers: {
    "x-api-key": Schema.String,
    "x-request-id": Schema.String
  },
  success: Schema.Array(User)
})

handlers.handle("getUsers", (ctx) => {
  const apiKey = ctx.headers["x-api-key"]
  return Effect.succeed([])
})
```

## Multipart Requests

Use `HttpApiSchema.asMultipart` for file uploads. `Multipart.FilesSchema` handles file persistence:

```ts
import { Multipart } from "effect/unstable/http"
import { HttpApiSchema } from "effect/unstable/httpapi"

HttpApiEndpoint.post("upload", "/upload", {
  payload: HttpApiSchema.asMultipart(
    Schema.Struct({
      files: Multipart.FilesSchema
    })
  ),
  success: Schema.String
})

handlers.handle("upload", (ctx) => {
  const { files } = ctx.payload
  // files: readonly Multipart.PersistedFile[]
  console.log(files)
  return Effect.succeed("Uploaded")
})
```

## Request Encoding

| Encoding | Helper | Content-Type |
|----------|--------|-------------|
| JSON (default) | `HttpApiSchema.asJson()` | application/json |
| Form URL-encoded | `HttpApiSchema.asFormUrlEncoded()` | application/x-www-form-urlencoded |
| Plain text | `HttpApiSchema.asText()` | text/plain |
| Binary | `HttpApiSchema.asUint8Array()` | application/octet-stream |

```ts
// Form-encoded request body
HttpApiEndpoint.post("createUser", "/user", {
  payload: Schema.Struct({
    name: Schema.String,
    email: Schema.String
  }).pipe(HttpApiSchema.asFormUrlEncoded()),
  success: User
})

// Binary/streaming request
HttpApiEndpoint.post("upload", "/upload", {
  payload: Schema.Uint8Array.pipe(HttpApiSchema.asUint8Array()),
  success: Schema.String
})

handlers.handle("upload", (ctx) => {
  const data = ctx.payload  // Uint8Array
  return Effect.succeed(new TextDecoder().decode(data))
})
```

## Accessing the Raw Request

Use `ctx.request` for low-level access to the `HttpServerRequest`:

```ts
handlers.handle("endpoint", (ctx) => {
  const req = ctx.request
  console.log(req.method)  // "GET", "POST", etc.
  console.log(req.url)     // "/users?page=1"
  
  // Read cookies directly (not validated)
  const lang = req.cookies.lang ?? "en"
  
  return Effect.succeed("result")
})
```

## Streaming Requests

For large or continuous data, use `HttpApiSchema.asUint8Array()`:

```ts
HttpApiEndpoint.post("acceptStream", "/stream", {
  payload: Schema.Uint8Array.pipe(
    HttpApiSchema.asUint8Array()
  ),
  success: Schema.String
})

handlers.handle("acceptStream", (ctx) => {
  const data = ctx.payload  // Uint8Array
  return Effect.succeed(new TextDecoder().decode(data))
})
```