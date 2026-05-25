# HTTP API — Response Handling

## Status Codes

Default is `200 OK`. Use `HttpApiSchema.status()` to customize:

```ts
// 206 Partial Content
HttpApiEndpoint.get("getUsers", "/users", {
  success: Schema.Array(User).pipe(HttpApiSchema.status(206))
})

// 201 Created
HttpApiEndpoint.post("createUser", "/users", {
  payload: User,
  success: User.pipe(HttpApiSchema.status(201))
})

// Default 200 with Schema.Void = 204 No Content
HttpApiEndpoint.delete("deleteUser", "/user/:id", {
  params: { id: Schema.Int },
  success: Schema.Void
})
```

## Response Encoding

| Encoding | Helper | Default Content-Type |
|----------|--------|---------------------|
| JSON | `HttpApiSchema.asJson()` | application/json |
| Text | `HttpApiSchema.asText()` | text/plain |
| Binary | `HttpApiSchema.asUint8Array()` | application/octet-stream |

```ts
// CSV response
HttpApiEndpoint.get("csv", "/users/csv", {
  success: Schema.String.pipe(
    HttpApiSchema.asText({ contentType: "text/csv" })
  )
})

handlers.handle("csv", () =>
  Effect.succeed("id,name\n1,John\n2,Jane")
)

// Binary response
HttpApiEndpoint.get("download", "/download", {
  success: Schema.Uint8Array.pipe(HttpApiSchema.asUint8Array())
})
```

## Response Headers

Add custom headers with `HttpEffect.appendPreResponseHandler`:

```ts
import { HttpEffect, HttpServerResponse } from "effect/unstable/http"

handlers.handle("endpoint", () =>
  Effect.gen(function*() {
    yield* HttpEffect.appendPreResponseHandler((_req, response) =>
      Effect.succeed(HttpServerResponse.setHeader(response, "x-custom", "hello"))
    )
    return "result"
  })
)
```

## Cookies

Set cookies via `HttpEffect.appendPreResponseHandler` with `HttpServerResponse.setCookieUnsafe`:

```ts
handlers.handle("hello", () =>
  Effect.gen(function*() {
    yield* HttpEffect.appendPreResponseHandler((_req, response) =>
      Effect.succeed(
        HttpServerResponse.setCookieUnsafe(response, "my-cookie", "my-value", {
          httpOnly: true,
          secure: true,
          path: "/"
        })
      )
    )
    return "Hello!"
  })
)
```

## Redirects

Return `HttpServerResponse.redirect` from the handler:

```ts
import { HttpServerResponse } from "effect/unstable/http"

HttpApiEndpoint.get("oldPage", "/old")

handlers.handle("oldPage", () =>
  Effect.succeed(HttpServerResponse.redirect("/new", { status: 302 }))
)
```

The endpoint schema-wise is "no content" — redirect headers aren't modeled in the schema.

## Streaming Responses

Return `HttpServerResponse.stream` for streaming data:

```ts
import { HttpServerResponse, Stream, Schedule } from "effect/unstable/http"

HttpApiEndpoint.get("stream", "/stream", {
  success: Schema.String.pipe(
    HttpApiSchema.asText({ contentType: "application/octet-stream" })
  )
})

const stream = Stream.make("a", "b", "c").pipe(
  Stream.schedule(Schedule.spaced("500 millis")),
  Stream.map((s) => new TextEncoder().encode(s))
)

handlers.handle("stream", () =>
  Effect.succeed(HttpServerResponse.stream(stream))
)
```