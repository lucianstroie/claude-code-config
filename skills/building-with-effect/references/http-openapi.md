# HTTP API — OpenAPI & Documentation

## Serving Documentation

Add Scalar or Swagger UI via layer:

```ts
import { HttpApiScalar, HttpApiSwagger } from "effect/unstable/httpapi";

const ApiLive = HttpApiBuilder.layer(Api).pipe(
  Layer.provide(GroupLive),
  Layer.provide(HttpApiScalar.layer(Api)), // Scalar at /docs
  // or Layer.provide(HttpApiSwagger.layer(Api)), // Swagger at /docs
  HttpRouter.serve,
  Layer.provide(NodeHttpServer.layer(createServer, { port: 3000 })),
);
```

Both modules serve interactive documentation at `/docs`.

## OpenAPI Annotations

Use `.annotate()` on `HttpApi`, `HttpApiGroup`, or `HttpApiEndpoint` to add metadata to the generated spec.

### HttpApi Annotations

| Annotation                  | Description          |
| --------------------------- | -------------------- |
| `OpenApi.Title`             | API title            |
| `OpenApi.Description`       | API description      |
| `OpenApi.Version`           | API version          |
| `OpenApi.Servers`           | Server URLs          |
| `OpenApi.License`           | License info         |
| `OpenApi.Summary`           | Brief summary        |
| `OpenApi.AdditionalSchemas` | Custom schemas       |
| `OpenApi.Override`          | Merge custom fields  |
| `OpenApi.Transform`         | Transform final spec |

```ts
import { OpenApi } from "effect/unstable/httpapi"

const Api = HttpApi.make("MyApi")
  .annotate(OpenApi.Title, "My API")
  .annotate(OpenApi.Description, "User management API")
  .annotate(OpenApi.Version, "1.0.0")
  .annotate(OpenApi.Servers, [{ url: "https://api.example.com" }])
  .annotate(OpenApi.License, { name: "MIT", url: "https://opensource.org/licenses/MIT" })
  .add(
    HttpApiGroup.make("Users").add(...)
  )
```

### HttpApiGroup Annotations

| Annotation             | Description          |
| ---------------------- | -------------------- |
| `OpenApi.Description`  | Group description    |
| `OpenApi.ExternalDocs` | External docs link   |
| `OpenApi.Exclude`      | Exclude from spec    |
| `OpenApi.Override`     | Merge custom fields  |
| `OpenApi.Transform`    | Transform group spec |

```ts
HttpApiGroup.make("users")
  .annotate(OpenApi.Description, "User management operations")
  .annotate(OpenApi.ExternalDocs, {
    url: "https://docs.example.com/users",
    description: "User documentation"
  })
  .annotate(OpenApi.Exclude, true) // hide from docs
  .add(...)
```

### HttpApiEndpoint Annotations

| Annotation             | Description             |
| ---------------------- | ----------------------- |
| `OpenApi.Description`  | Endpoint description    |
| `OpenApi.Summary`      | Brief summary           |
| `OpenApi.Deprecated`   | Mark as deprecated      |
| `OpenApi.ExternalDocs` | External docs link      |
| `OpenApi.Exclude`      | Exclude from spec       |
| `OpenApi.Override`     | Merge custom fields     |
| `OpenApi.Transform`    | Transform endpoint spec |

```ts
HttpApiEndpoint.get("getUser", "/users/:id", { success: User })
  .annotate(OpenApi.Description, "Retrieve a user by ID")
  .annotate(OpenApi.Summary, "Get user")
  .annotate(OpenApi.Deprecated, false)
  .annotate(OpenApi.ExternalDocs, {
    url: "https://docs.example.com/users#get",
    description: "Related documentation",
  });
```

## Response Descriptions

Annotate success schemas for custom response descriptions:

```ts
success: Schema.Array(User).annotate({
  description: "Returns all users in the system",
});
```

Default response description is "Success".

## Top-Level Groups

When `topLevel: true`, the group name is not prepended to operation IDs and client methods are not nested:

```ts
HttpApiGroup.make("Users", { topLevel: true }).add(
  HttpApiEndpoint.get("getUsers", "/users", { success: Schema.Array(User) }),
);

// Client: client.getUsers() instead of client.Users.getUsers()

// OpenAPI operationId: "getUsers" instead of "Users.getUsers"
```

Use `topLevel` when the group is just for organization but you want cleaner operation IDs and direct client methods.

## Schema Annotations

For schemas used in API definitions, add `identifier` for named schemas in docs:

```ts
const User = Schema.Struct({
  id: Schema.Int,
  name: Schema.String,
}).annotate({
  identifier: "User",
  description: "A user entity",
});
```

## Additional Schemas

Add custom schemas to the OpenAPI spec:

```ts
HttpApi.make("api").annotate(HttpApi.AdditionalSchemas, [
  Schema.String.annotate({ identifier: "MyString" }),
]);
```

## Transform Final Spec

Modify the generated specification with a function:

```ts
HttpApi.make("api").annotate(OpenApi.Transform, (spec) => ({
  ...spec,
  tags: [...spec.tags, { name: "internal", description: "Internal endpoints" }],
}));
```

Or override parts of the spec:

```ts
HttpApi.make("api").annotate(OpenApi.Override, {
  tags: [{ name: "a", description: "a-description" }],
});
```

