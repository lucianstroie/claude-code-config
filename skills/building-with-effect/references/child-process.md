# Child Process

Working with child processes in Effect.

See related examples in [effect-smol/ai-docs/src/60_child-process/](https://github.com/Effect-TS/effect-smol/tree/main/ai-docs/src/60_child-process/)

## Overview

The `effect/unstable/process` module provides utilities for:

- Running external commands
- Capturing output (stdout/stderr)
- Streaming long-running processes
- Composing command pipelines
- Managing process lifecycle

## Setup

```ts
import { NodeServices } from "@effect/platform-node";
import { ChildProcess, ChildProcessSpawner } from "effect/unstable/process";
```

## Basic Usage

### Simple Commands

```ts
import {
  Console,
  Effect,
  Layer,
  Schema,
  Context,
  Stream,
  String,
} from "effect";

class DevToolsError extends Schema.TaggedErrorClass<DevToolsError>()(
  "DevToolsError",
  { cause: Schema.Defect },
) {}

export class DevTools extends Context.Service<
  DevTools,
  {
    readonly nodeVersion: Effect.Effect<string, DevToolsError>;
    readonly recentCommitSubjects: Effect.Effect<
      ReadonlyArray<string>,
      DevToolsError
    >;
    readonly runLintFix: Effect.Effect<void, DevToolsError>;
    changedTypeScriptFiles(
      baseRef: string,
    ): Effect.Effect<ReadonlyArray<string>, DevToolsError>;
  }
>()("docs/DevTools") {
  static readonly layer = Layer.effect(
    DevTools,
    Effect.gen(function* () {
      const spawner = yield* ChildProcessSpawner.ChildProcessSpawner;

      // Get output as string
      const nodeVersion = spawner
        .string(ChildProcess.make("node", ["--version"]))
        .pipe(
          Effect.map(String.trim),
          Effect.mapError((cause) => new DevToolsError({ cause })),
        );

      // Get output as lines
      const changedTypeScriptFiles = Effect.fn(
        "DevTools.changedTypeScriptFiles",
      )(function* (baseRef: string) {
        yield* Effect.annotateCurrentSpan({ baseRef });

        const files = yield* spawner
          .lines(
            ChildProcess.make("git", [
              "diff",
              "--name-only",
              `${baseRef}...HEAD`,
            ]),
          )
          .pipe(Effect.mapError((cause) => new DevToolsError({ cause })));

        return files.filter((file) => file.endsWith(".ts"));
      });

      // Command pipeline
      const recentCommitSubjects = spawner
        .lines(
          ChildProcess.make("git", [
            "log",
            "--pretty=format:%s",
            "-n",
            "20",
          ]).pipe(ChildProcess.pipeTo(ChildProcess.make("head", ["-n", "5"]))),
        )
        .pipe(Effect.mapError((cause) => new DevToolsError({ cause })));

      // Stream output while running
      const runLintFix = Effect.gen(function* () {
        const handle = yield* spawner
          .spawn(
            ChildProcess.make("pnpm", ["lint-fix"], {
              env: { FORCE_COLOR: "1" },
              extendEnv: true,
            }),
          )
          .pipe(Effect.mapError((cause) => new DevToolsError({ cause })));

        // Stream stdout
        yield* handle.stdout.pipe(
          Stream.decodeText(),
          Stream.splitLines,
          Stream.runForEach((line) => Console.log(`[lint-fix] ${line}`)),
          Effect.mapError((cause) => new DevToolsError({ cause })),
        );

        // Wait for exit
        const exitCode = yield* handle.exitCode.pipe(
          Effect.mapError((cause) => new DevToolsError({ cause })),
        );

        if (exitCode !== ChildProcessSpawner.ExitCode(0)) {
          return yield* new DevToolsError({
            cause: new Error(`pnpm lint-fix failed with exit code ${exitCode}`),
          });
        }
      }).pipe(Effect.scoped); // spawner.spawn adds Scope requirement

      return DevTools.of({
        nodeVersion,
        changedTypeScriptFiles,
        recentCommitSubjects,
        runLintFix,
      });
    }),
  ).pipe(Layer.provide(NodeServices.layer));
}
```

## Command Options

```ts
ChildProcess.make("command", ["arg1", "arg2"], {
  cwd: "/path/to/working/dir",
  env: { CUSTOM_VAR: "value" },
  extendEnv: true, // Merge with current env
  shell: false, // Use shell
  timeout: 30000, // Timeout in ms
});
```

## Best Practices

1. **Use spawner.string** for simple output capture
2. **Use spawner.lines** for line-oriented output
3. **Use spawner.spawn** for streaming long-running processes
4. **Always scope spawned processes** with `Effect.scoped`
5. **Check exit codes** for error handling
6. **Stream output** for real-time feedback on long commands
7. **Use annotations** for tracing

## Common Patterns

### Running Tests

```ts
const runTests = Effect.gen(function* () {
  const handle = yield* spawner.spawn(ChildProcess.make("npm", ["test"]));

  yield* handle.all.pipe(Stream.decodeText(), Stream.runForEach(Console.log));

  const exitCode = yield* handle.exitCode;
  if (exitCode !== 0) {
    return yield* Effect.fail("Tests failed");
  }
});
```

### File Processing Pipeline

```ts
const processFiles = spawner.string(
  ChildProcess.make("find", [".", "-name", "*.ts"]).pipe(
    ChildProcess.pipeTo(ChildProcess.make("wc", ["-l"])),
  ),
);
```
