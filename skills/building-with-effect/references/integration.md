# Integration

Integrating Effect with non-Effect code using ManagedRuntime.

See related examples in [effect-smol/ai-docs/src/03_integration/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/03_integration/)

## Overview

`ManagedRuntime` bridges Effect programs with non-Effect code. Use it when:

- Working with existing frameworks (Express, Fastify, Hono)
- Integrating with legacy codebases
- Building serverless functions
- Using callback-based APIs

## Basic Usage

### Creating a ManagedRuntime

```ts
import { Effect, Layer, ManagedRuntime, Schema, Context } from "effect";
import { Hono } from "hono";

class Todo extends Schema.Class<Todo>("Todo")({
  id: Schema.Number,
  title: Schema.String,
  completed: Schema.Boolean,
}) {}

class CreateTodoPayload extends Schema.Class<CreateTodoPayload>(
  "CreateTodoPayload",
)({
  title: Schema.String,
}) {}

class TodoNotFound extends Schema.TaggedErrorClass<TodoNotFound>()(
  "TodoNotFound",
  { id: Schema.Number },
) {}

export class TodoRepo extends Context.Service<
  TodoRepo,
  {
    readonly getAll: Effect.Effect<ReadonlyArray<Todo>>;
    getById(id: number): Effect.Effect<Todo, TodoNotFound>;
    create(payload: CreateTodoPayload): Effect.Effect<Todo>;
  }
>()("app/TodoRepo") {
  static readonly layer = Layer.effect(
    TodoRepo,
    Effect.gen(function* () {
      const store = new Map<number, Todo>();
      let nextId = 1;

      const getAll = Effect.sync(() => Array.from(store.values()));

      const getById = Effect.fn("TodoRepo.getById")(function* (id: number) {
        const todo = store.get(id);
        if (todo === undefined) {
          return yield* new TodoNotFound({ id });
        }
        return todo;
      });

      const create = Effect.fn("TodoRepo.create")(function* (
        payload: CreateTodoPayload,
      ) {
        const todo = new Todo({
          id: nextId++,
          title: payload.title,
          completed: false,
        });
        store.set(todo.id, todo);
        return todo;
      });

      return TodoRepo.of({ getAll, getById, create });
    }),
  );
}

// Create memo map for sharing across requests
export const appMemoMap = Layer.makeMemoMapUnsafe();

// Create runtime from layer
export const runtime = ManagedRuntime.make(TodoRepo.layer, {
  memoMap: appMemoMap,
});
```

### Using with Hono

```ts
const app = new Hono();

app.get("/todos", async (context) => {
  const todos = await runtime.runPromise(TodoRepo.use((repo) => repo.getAll));
  return context.json(todos);
});

app.get("/todos/:id", async (context) => {
  const id = Number(context.req.param("id"));

  if (!Number.isFinite(id)) {
    return context.json({ message: "Todo id must be a number" }, 400);
  }

  const todo = await runtime.runPromise(
    TodoRepo.use((repo) => repo.getById(id)).pipe(
      Effect.catchTag("TodoNotFound", () => Effect.succeed(null)),
    ),
  );

  if (todo === null) {
    return context.json({ message: "Todo not found" }, 404);
  }

  return context.json(todo);
});

app.post("/todos", async (context) => {
  const body = await context.req.json();

  let payload: CreateTodoPayload;
  try {
    payload = Schema.decodeUnknownSync(CreateTodoPayload)(body);
  } catch {
    return context.json({ message: "Invalid request body" }, 400);
  }

  const todo = await runtime.runPromise(
    TodoRepo.use((repo) => repo.create(payload)),
  );

  return context.json(todo, 201);
});

// Cleanup on shutdown
const shutdown = () => {
  void runtime.dispose();
};

process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
```

## Other Frameworks

### Express

```ts
import express from "express";

const app = express();
app.use(express.json());

app.get("/todos", async (req, res) => {
  try {
    const todos = await runtime.runPromise(TodoRepo.use((repo) => repo.getAll));
    res.json(todos);
  } catch (error) {
    res.status(500).json({ error: "Internal server error" });
  }
});
```

### Fastify

```ts
import Fastify from "fastify";

const fastify = Fastify();

fastify.get("/todos", async () => {
  return runtime.runPromise(TodoRepo.use((repo) => repo.getAll));
});
```

### Next.js API Routes

```ts
// pages/api/todos.ts
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse,
) {
  if (req.method === "GET") {
    const todos = await runtime.runPromise(TodoRepo.use((repo) => repo.getAll));
    res.status(200).json(todos);
  }
}
```

## Serverless

### AWS Lambda

```ts
export const handler = async (event: APIGatewayEvent) => {
  const result = await runtime.runPromise(
    Effect.gen(function* () {
      // Effect logic here
      return { statusCode: 200, body: "Hello" };
    }),
  );

  return result;
};
```

### Vercel Edge

```ts
export const config = {
  runtime: "edge",
};

export default async function handler(request: Request) {
  const result = await runtime.runPromise(
    Effect.gen(function* () {
      return new Response("Hello from Effect");
    }),
  );

  return result;
}
```

## Callback Integration

### runCallback

```ts
runtime.runCallback(effect, (exit) => {
  if (Exit.isSuccess(exit)) {
    console.log("Success:", exit.value);
  } else {
    console.error("Failure:", exit.cause);
  }
});
```

### runSync

```ts
const result = runtime.runSync(effect);
// Synchronous execution (unsafe for async effects)
```

## Best Practices

1. **Create runtime once** at module level or in factory function
2. **Use memoMap** for sharing layer instances across requests
3. **Dispose on shutdown** to clean up resources
4. **Handle errors** in the non-Effect boundary
5. **Use Schema.decodeUnknownSync** for request validation
6. **Catch errors** and convert to HTTP responses
7. **Keep Effect code pure** - side effects only at boundaries

## Common Patterns

### Request Context

```ts
const withRequestContext = (req: Request) =>
  Effect.provideService(program, RequestContext, {
    requestId: req.headers["x-request-id"],
  });

app.use(async (req, res, next) => {
  req.effectRuntime = {
    run: (effect: Effect.Effect<A, E, R>) =>
      runtime.runPromise(withRequestContext(req)(effect)),
  };
  next();
});
```

### Error Handling Middleware

```ts
const errorHandler = (error: unknown, res: Response) => {
  if (error instanceof TodoNotFound) {
    return res.status(404).json({ message: "Not found" });
  }

  if (error instanceof ValidationError) {
    return res.status(400).json({ message: error.message });
  }

  return res.status(500).json({ message: "Internal error" });
};
```

### Health Check

```ts
app.get("/health", async (req, res) => {
  const healthy = await runtime.runPromise(
    Effect.gen(function* () {
      yield* TodoRepo.use((repo) => repo.getAll);
      return true;
    }).pipe(
      Effect.timeout("5 seconds"),
      Effect.orElseSucceed(() => false),
    ),
  );

  res.status(healthy ? 200 : 503).json({ healthy });
});
```
