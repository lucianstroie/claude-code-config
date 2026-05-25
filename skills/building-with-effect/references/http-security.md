# HTTP API — Middleware & Security

## Middleware

Define middleware as a class extending `HttpApiMiddleware.Service`. Middleware runs shared logic before/around handlers.

### Defining Middleware

```ts
import { HttpApiMiddleware, HttpApiSchema } from "effect/unstable/httpapi"
import { Schema } from "effect"

class Logger extends HttpApiMiddleware.Service<Logger>()("Logger", {
  error: Schema.String.pipe(
    HttpApiSchema.status(405),
    HttpApiSchema.asText()
  )
}) {}
```

### Implementing Middleware

Implement as a `Layer` that returns a handler function:

```ts
import { HttpServerRequest } from "effect/unstable/http"

const LoggerLive = Layer.effect(
  Logger,
  Effect.gen(function*() {
    yield* Effect.log("creating Logger middleware")

    return (res) =>
      Effect.gen(function*() {
        const request = yield* HttpServerRequest.HttpServerRequest
        yield* Effect.log(`Request: ${request.method} ${request.url}`)
        return yield* res
      })
  })
)
```

### Applying Middleware

Apply to endpoint, group, or API:

```ts
// Endpoint-level
HttpApiEndpoint.get("endpoint", "/", { success: Schema.String })
  .middleware(Logger)

// Group-level
HttpApiGroup.make("group")
  .middleware(Logger)
  .add(...)

// API-level
HttpApi.make("api")
  .middleware(Logger)
  .add(...)
```

## Security Schemes

`HttpApiSecurity` declares how an endpoint is protected. These appear in OpenAPI docs and are enforced via middleware.

| Type | Function | Description |
|------|----------|-------------|
| API Key | `HttpApiSecurity.apiKey({ in: "header"\|"query"\|"cookie", key: "name" })` | Key in header/query/cookie |
| Basic | `HttpApiSecurity.basic()` | HTTP Basic auth |
| Bearer | `HttpApiSecurity.bearer()` | Bearer token |

### API Key Examples

```ts
// Header API key
const headerKey = HttpApiSecurity.apiKey({ in: "header", key: "X-API-Key" })

// Query API key
const queryKey = HttpApiSecurity.apiKey({ in: "query", key: "api_key" })

// Cookie API key
const cookieKey = HttpApiSecurity.apiKey({ in: "cookie", key: "session" })
```

### Bearer Token

```ts
const bearerSecurity = HttpApiSecurity.bearer()
```

## Security Middleware Implementation

```ts
import { Redacted, Context } from "effect"

class CurrentUser extends Context.Service<CurrentUser, { readonly id: number }>()("CurrentUser") {}

class Unauthorized extends Schema.TaggedErrorClass<Unauthorized>()(
  "Unauthorized",
  {},
  { httpApiStatus: 401 }
) {}

class Auth extends HttpApiMiddleware.Service<Auth, {
  provides: CurrentUser
}>()("Auth", {
  error: Unauthorized,
  security: { myBearer: HttpApiSecurity.bearer }
}) {}

const AuthLive = Layer.succeed(Auth, {
  myBearer: (effect, opts) =>
    Effect.provideServiceEffect(
      effect,
      CurrentUser,
      Effect.gen(function*() {
        const value = Redacted.value(opts.credential)
        if (value !== "valid-token") {
          return yield* Effect.fail(new Unauthorized({}))
        }
        return { id: 1 }
      })
    )
})
```

The handler receives `CurrentUser` via `yield*`:

```ts
handlers.handle("me", () =>
  Effect.gen(function*() {
    const user = yield* CurrentUser
    return { id: user.id }
  })
)
```

## Security Annotations

Add descriptions to security definitions for OpenAPI docs:

```ts
import { OpenApi } from "effect/unstable/httpapi"

HttpApiSecurity.bearer().pipe(
  HttpApiSecurity.annotate(OpenApi.Description, "JWT Bearer token")
)
```

## Setting Security Cookies

Use `HttpApiBuilder.securitySetCookie` to set auth cookies:

```ts
import { Redacted } from "effect"
import { HttpApiBuilder } from "effect/unstable/httpapi"

const security = HttpApiSecurity.apiKey({ in: "cookie", key: "token" })

handlers.handle("login", () =>
  HttpApiBuilder.securitySetCookie(security, Redacted.make("token-value"))
)
```

The cookie is created with `HttpOnly` and `Secure` flags by default.

## Cookie-Based Authentication

Validated cookie access uses security middleware:

```ts
const sessionCookie = HttpApiSecurity.apiKey({ in: "cookie", key: "session" })

class Auth extends HttpApiMiddleware.Service<Auth, {
  provides: CurrentUser
}>()("Auth", {
  error: Schema.String.annotate({ httpApiStatus: 401 }),
  security: { session: sessionCookie }
}) {}

const AuthLive = Layer.succeed(Auth, {
  session: (effect, opts) =>
    Effect.provideServiceEffect(
      effect,
      CurrentUser,
      Effect.gen(function*() {
        const value = Redacted.value(opts.credential)
        if (value !== "valid-session") {
          return yield* Effect.fail("Invalid session")
        }
        return { id: 1, name: "John Doe" }
      })
    )
})
```

For quick unvalidated access, read cookies directly from `ctx.request.cookies`. These won't appear in OpenAPI spec. See [http-request.md](http-request.md).