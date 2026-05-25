# HTTP API — Error Handling

## Custom Error Responses

Define error schemas with `HttpApiSchema.status()`:

```ts
import { HttpApiSchema } from "effect/unstable/httpapi"

const UserNotFound = Schema.Struct({
  _tag: Schema.tag("UserNotFound"),
  message: Schema.String
}).pipe(HttpApiSchema.status(404))

const Unauthorized = Schema.Struct({
  _tag: Schema.tag("Unauthorized")
}).pipe(HttpApiSchema.status(401))
```

Use in endpoint definitions:

```ts
HttpApiEndpoint.get("getUser", "/user/:id", {
  params: { id: Schema.Int },
  success: User,
  error: [UserNotFound, Unauthorized]
})
```

Fail in handlers with `Effect.fail`:

```ts
handlers.handle("getUser", (ctx) => {
  const id = ctx.params.id
  if (id === 1) {
    return Effect.fail(UserNotFound.make({ message: "User not found" }))
  }
  return Effect.succeed({ id, name: `User ${id}` })
})
```

## Predefined Error Types

The `HttpApiError` module provides ready-made error schemas:

| Name | Status | Description |
|------|--------|-------------|
| `HttpApiError.BadRequest` | 400 | Malformed request |
| `HttpApiError.Unauthorized` | 401 | Missing/invalid authentication |
| `HttpApiError.Forbidden` | 403 | Permission denied |
| `HttpApiError.NotFound` | 404 | Resource not found |
| `HttpApiError.MethodNotAllowed` | 405 | HTTP method not allowed |
| `HttpApiError.NotAcceptable` | 406 | Format not acceptable |
| `HttpApiError.RequestTimeout` | 408 | Request timed out |
| `HttpApiError.Conflict` | 409 | Resource conflict |
| `HttpApiError.Gone` | 410 | Resource permanently gone |
| `HttpApiError.InternalServerError` | 500 | Unexpected server error |
| `HttpApiError.NotImplemented` | 501 | Not implemented |
| `HttpApiError.ServiceUnavailable` | 503 | Temporarily unavailable |

```ts
import { HttpApiError } from "effect/unstable/httpapi"

HttpApiEndpoint.get("getUser", "/user/:id", {
  params: { id: Schema.Int },
  success: User,
  error: [
    HttpApiError.NotFound,
    HttpApiError.Unauthorized
  ]
})

handlers.handle("getUser", (ctx) => {
  const id = ctx.params.id
  if (id === 1) {
    return Effect.fail(new HttpApiError.NotFound({}))
  }
  return Effect.succeed({ id, name: `User ${id}` })
})
```

## NoContent Variants

Each predefined error has a `NoContent` variant that responds with the status code but no body:

```ts
HttpApiEndpoint.get("getUser", "/user/:id", {
  params: { id: Schema.Int },
  success: User,
  error: [
    HttpApiError.NotFoundNoContent,
    HttpApiError.UnauthorizedNoContent
  ]
})
```

## HttpApiDecodeError

Automatically generated for request validation failures (400 Bad Request with detailed issues).

## Error Response Format

Errors follow this structure:

```ts
{
  _tag: "HttpApiSchemaError",
  message: "...",
  issues: [...]  // detailed validation issues
}
```

For custom errors with `Schema.tag`, the `_tag` enables discriminated unions:

```ts
const UserNotFound = Schema.Struct({
  _tag: Schema.tag("UserNotFound"),
  message: Schema.String
})

const NotAuthorized = Schema.Struct({
  _tag: Schema.tag("NotAuthorized"),
  message: Schema.String
})

// Client can match on _tag to handle different error types
```