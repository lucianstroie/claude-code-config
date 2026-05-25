# CLI

Building command-line applications with Effect CLI.

See related examples in [effect-smol/ai-docs/src/70_cli/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/70_cli/)

## Overview

The `effect/unstable/cli` module provides utilities for:

- Parsing command-line arguments
- Defining flags and options
- Creating subcommands
- Type-safe CLI applications

## Setup

```ts
import { NodeRuntime, NodeServices } from "@effect/platform-node";
import { Console, Effect } from "effect";
import { Argument, Command, Flag } from "effect/unstable/cli";
```

## Basic CLI

### Define Commands

```ts
// Reusable flags
const workspace = Flag.string("workspace").pipe(
  Flag.withAlias("w"),
  Flag.withDescription("Workspace to operate on"),
  Flag.withDefault("personal"),
);

// Root command with shared flags
const tasks = Command.make("tasks").pipe(
  Command.withSharedFlags({
    workspace,
    verbose: Flag.boolean("verbose").pipe(
      Flag.withAlias("v"),
      Flag.withDescription("Print diagnostic output"),
    ),
  }),
  Command.withDescription("Track and manage tasks"),
);

// Create subcommand
const create = Command.make(
  "create",
  {
    title: Argument.string("title").pipe(
      Argument.withDescription("Task title"),
    ),
    priority: Flag.choice("priority", ["low", "normal", "high"]).pipe(
      Flag.withDescription("Priority for the new task"),
      Flag.withDefault("normal"),
    ),
  },
  Effect.fn(function* ({ title, priority }) {
    const root = yield* tasks;

    if (root.verbose) {
      yield* Console.log(`workspace=${root.workspace} action=create`);
    }

    yield* Console.log(
      `Created "${title}" in ${root.workspace} with ${priority} priority`,
    );
  }),
).pipe(
  Command.withDescription("Create a task"),
  Command.withExamples([
    {
      command: 'tasks create "Ship 4.0" --priority high',
      description: "Create a high-priority task",
    },
  ]),
);

// List subcommand
const list = Command.make(
  "list",
  {
    status: Flag.choice("status", ["open", "done", "all"]).pipe(
      Flag.withDescription("Filter tasks by status"),
      Flag.withDefault("open"),
    ),
    json: Flag.boolean("json").pipe(
      Flag.withDescription("Print machine-readable output"),
    ),
  },
  Effect.fn(function* ({ status, json }) {
    const root = yield* tasks;

    const items = [
      { title: "Ship 4.0", status: "open" },
      { title: "Update onboarding guide", status: "done" },
    ] as const;

    const filtered =
      status === "all" ? items : items.filter((item) => item.status === status);

    if (root.verbose) {
      yield* Console.log(`workspace=${root.workspace} action=list`);
    }

    if (json) {
      yield* Console.log(
        JSON.stringify(
          {
            workspace: root.workspace,
            status,
            items: filtered,
          },
          null,
          2,
        ),
      );
      return;
    }

    yield* Console.log(`Listing ${status} tasks in ${root.workspace}`);

    if (filtered.length === 0) {
      yield* Console.log("- No tasks found");
      return;
    }

    for (const item of filtered) {
      yield* Console.log(`- ${item.title}`);
    }
  }),
).pipe(
  Command.withDescription("List tasks"),
  Command.withAlias("ls"),
  Command.withExamples([
    {
      command: "tasks --workspace team-a list --status open",
      description: "List open tasks in a specific workspace",
    },
  ]),
);

// Compose and run
tasks.pipe(
  Command.withSubcommands([create, list]),
  Command.run({
    version: "1.0.0",
  }),
  Effect.provide(NodeServices.layer),
  NodeRuntime.runMain,
);
```

## Flag Types

### Boolean Flags

```ts
const verbose = Flag.boolean("verbose").pipe(
  Flag.withAlias("v"),
  Flag.withDescription("Enable verbose output"),
);
```

### String Flags

```ts
const name = Flag.string("name").pipe(
  Flag.withDescription("Your name"),
  Flag.withDefault("Anonymous"),
);
```

### Number Flags

```ts
const port = Flag.number("port").pipe(
  Flag.withDescription("Server port"),
  Flag.withDefault(3000),
);
```

### Choice Flags

```ts
const env = Flag.choice("env", ["dev", "staging", "prod"]).pipe(
  Flag.withDescription("Environment"),
  Flag.withDefault("dev"),
);
```

### Array Flags

```ts
const tags = Flag.array("tag").pipe(
  Flag.withDescription("Tags (can be specified multiple times)"),
);
// Usage: --tag foo --tag bar
```

## Arguments

### Positional Arguments

```ts
const copy = Command.make(
  "copy",
  {
    source: Argument.string("source").pipe(
      Argument.withDescription("Source file path"),
    ),
    dest: Argument.string("destination").pipe(
      Argument.withDescription("Destination file path"),
    ),
  },
  Effect.fn(function* ({ source, dest }) {
    yield* Console.log(`Copying ${source} to ${dest}`);
  }),
);
```

### Optional Arguments

```ts
const greet = Command.make(
  "greet",
  {
    name: Argument.string("name").pipe(
      Argument.withDescription("Name to greet"),
      Argument.withDefault("World"),
    ),
  },
  Effect.fn(function* ({ name }) {
    yield* Console.log(`Hello, ${name}!`);
  }),
);
```

## Subcommands

### Nested Commands

```ts
const database = Command.make("db").pipe(
  Command.withDescription("Database operations"),
);

const dbMigrate = Command.make(
  "migrate",
  {},
  Effect.fn(function* () {
    yield* Console.log("Running migrations...");
  }),
);

const dbSeed = Command.make(
  "seed",
  {},
  Effect.fn(function* () {
    yield* Console.log("Seeding database...");
  }),
);

database.pipe(Command.withSubcommands([dbMigrate, dbSeed]));
```

## Validation

### Custom Validation

```ts
const port = Flag.number("port").pipe(
  Flag.withDescription("Server port"),
  Flag.withDefault(3000),
  Flag.validate((value) => {
    if (value < 1 || value > 65535) {
      return Effect.fail("Port must be between 1 and 65535");
    }
    return Effect.succeed(value);
  }),
);
```

## Best Practices

1. **Use descriptive names** for flags and commands
2. **Add aliases** for commonly used flags
3. **Provide examples** in command definitions
4. **Use shared flags** for common options
5. **Set sensible defaults** for optional flags
6. **Validate inputs** early with custom validators
7. **Group related commands** with subcommands
8. **Document everything** with descriptions

## Common Patterns

### Configuration File

```ts
const config = Command.make(
  "config",
  {
    key: Argument.string("key"),
    value: Argument.string("value").pipe(Argument.optional),
  },
  Effect.fn(function* ({ key, value }) {
    if (value === undefined) {
      // Get config value
      const current = yield* getConfig(key);
      yield* Console.log(`${key}=${current}`);
    } else {
      // Set config value
      yield* setConfig(key, value);
      yield* Console.log(`Set ${key}=${value}`);
    }
  }),
);
```

### Interactive Prompt

```ts
const interactive = Command.make(
  "interactive",
  {},
  Effect.fn(function* () {
    yield* Console.log("Interactive mode (press Ctrl+C to exit)");

    while (true) {
      const input = yield* prompt("> ");
      yield* processCommand(input);
    }
  }),
);
```
