# AI Modules

Working with Effect's AI modules for LLM integration.

## Contents

- [Overview](#overview) - AI module capabilities
- [Setup](#setup) - Installing and configuring providers
- [Basic Text Generation](#basic-text-generation) - Simple generation patterns
- [Structured Object Generation](#structured-object-generation) - Using Schema
- [Streaming Responses](#streaming-responses) - Real-time text streaming
- [Provider Fallback with ExecutionPlan](#provider-fallback-with-executionplan) - Resilience patterns
- [Tool Calling](#tool-calling) - Implementing custom tools
- [Chat Sessions](#chat-sessions) - Conversational AI
- [Provider-Defined Tools](#provider-defined-tools) - Built-in provider tools
- [Best Practices](#best-practices) - Recommendations
- [Testing AI Services](#testing-ai-services) - Test patterns
- [Common Patterns](#common-patterns) - Retry, caching, parallel generation

## Overview

Effect's AI modules provide a provider-agnostic interface for:

- Text generation
- Structured object generation with Schema
- Streaming responses
- Tool calling
- Chat sessions with history

## Setup

### Install Provider Packages

```bash
# OpenAI
npm install @effect/ai-openai

# Anthropic
npm install @effect/ai-anthropic
```

### Configure Clients

```ts
import { OpenAiClient, OpenAiLanguageModel } from "@effect/ai-openai";
import { AnthropicClient, AnthropicLanguageModel } from "@effect/ai-anthropic";
import { Config, Effect, Layer } from "effect";
import { FetchHttpClient } from "effect/unstable/http";

// OpenAI client
const OpenAiClientLayer = OpenAiClient.layerConfig({
  apiKey: Config.redacted("OPENAI_API_KEY"),
}).pipe(Layer.provide(FetchHttpClient.layer));

// Anthropic client
const AnthropicClientLayer = AnthropicClient.layerConfig({
  apiKey: Config.redacted("ANTHROPIC_API_KEY"),
}).pipe(Layer.provide(FetchHttpClient.layer));
```

## Basic Text Generation

### Simple Generation

```ts
import { Effect, Layer, Schema, Context } from "effect";
import { LanguageModel } from "effect/unstable/ai";

import { AiError } from "effect/unstable/ai"

export class AiWriterError extends Schema.TaggedErrorClass<AiWriterError>()(
  "AiWriterError",
  { reason: AiError.AiErrorReason }
) {
  static fromAiError(error: AiError.AiError) {
    return new AiWriterError({ reason: error.reason })
  }
}

export class AiWriter extends Context.Service<
  AiWriter,
  {
    draftAnnouncement(product: string): Effect.Effect<
      { readonly provider: string; readonly text: string },
      AiWriterError
    >;
  }
>()("docs/AiWriter") {
  static readonly layer = Layer.effect(
    AiWriter,
    Effect.gen(function* () {
      // Get the default language model
      const model = yield* LanguageModel.LanguageModel;

      const draftAnnouncement = Effect.fn("AiWriter.draftAnnouncement")(
        function* (product: string) {
          const response = yield* model.generateText({
            prompt: `Write a short launch announcement for ${product}. Keep it concise and include one concrete user benefit.`,
          });

          yield* Effect.logInfo(
            `Model finished with ${response.finishReason}. Tokens: ${response.usage.outputTokens.total}`,
          );

          return { provider: response.provider, text: response.text };
        },
        Effect.mapError((error) => AiWriterError.fromAiError(error)),
      );

      return AiWriter.of({ draftAnnouncement });
    }),
  ).pipe(Layer.provide(OpenAiLanguageModel.model("gpt-5.2")));
}
```

### Generation with Specific Model

```ts
const modelLayer = OpenAiLanguageModel.model("gpt-5.2");

const generateWithModel = Effect.fn("generateWithModel")(function* (
  prompt: string,
) {
  const model = yield* LanguageModel.LanguageModel;
  const response = yield* model.generateText({ prompt });
  return { provider: response.provider, text: response.text };
}, Effect.provide(modelLayer));
```

## Structured Object Generation

### With Schema

```ts
import { Schema } from "effect";

class LaunchPlan extends Schema.Class<LaunchPlan>("LaunchPlan")({
  audience: Schema.String,
  channels: Schema.Array(Schema.String),
  launchDate: Schema.String,
  summary: Schema.String,
  keyRisks: Schema.Array(Schema.String),
}) {}

const extractLaunchPlan = Effect.fn("extractLaunchPlan")(function* (
  notes: string,
) {
  const model = yield* LanguageModel.LanguageModel;

  const response = yield* model.generateObject({
    objectName: "launch_plan",
    prompt: `Convert these notes into a launch plan:\n${notes}`,
    schema: LaunchPlan,
  });

  return response.value; // Typed as LaunchPlan
}, Effect.provide(modelLayer));
```

## Streaming Responses

### Text Streaming

```ts
import { Response, Stream } from "effect/unstable/ai";

const streamReleaseHighlights = (version: string) =>
  LanguageModel.streamText({
    prompt: `Write release highlights for version ${version} as a short bulleted list.`,
  }).pipe(
    Stream.filter(
      (part): part is Response.TextDeltaPart => part.type === "text-delta",
    ),
    Stream.map((part) => part.delta),
    Stream.provide(modelLayer),
    Stream.mapError((error) => AiWriterError.fromAiError(error)),
  );
```

## Provider Fallback with ExecutionPlan

### Define Fallback Strategy

```ts
import { ExecutionPlan } from "effect";

// Try primary model first, fall back to alternative
const DraftPlan = ExecutionPlan.make(
  { provide: OpenAiLanguageModel.model("gpt-5.2"), attempts: 3 },
  { provide: AnthropicLanguageModel.model("claude-opus-4-6"), attempts: 2 }
)

export class AiWriter extends Context.Service<
  AiWriter,
  {
    draftAnnouncement(product: string): Effect.Effect<
      { readonly provider: string; readonly text: string },
      AiWriterError
    >;
  }
>()("docs/AiWriter") {
  static readonly layer = Layer.effect(
    AiWriter,
    Effect.gen(function* () {
      // Get model with requirements moved to layer
      const draftsModel = yield* DraftPlan.withRequirements

      const draftAnnouncement = Effect.fn("AiWriter.draftAnnouncement")(
        function* (product: string) {
          const model = yield* LanguageModel.LanguageModel;
          const response = yield* model.generateText({
            prompt: `Write a launch announcement for ${product}`,
          });
          return { provider: response.provider, text: response.text };
        },
        Effect.withExecutionPlan(draftsModel),
        Effect.mapError((error) => AiWriterError.fromAiError(error)),
      );

      return AiWriter.of({ draftAnnouncement });
    }),
  ).pipe(Layer.provide([OpenAiClientLayer, AnthropicClientLayer]));
}
```

See full example: [ai-docs/src/71_ai/10_language-model.ts](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/71_ai/10_language-model.ts)

## Tool Calling

### Define Tools

```ts
import { AiError, LanguageModel, Tool, Toolkit } from "effect/unstable/ai";

const ProductId = Schema.String.pipe(Schema.brand("ProductId"));

class Product extends Schema.Class<Product>("Product")({
  id: ProductId,
  name: Schema.String,
  price: Schema.Number,
}) {}

const SearchProducts = Tool.make("SearchProducts", {
  description: "Search the product catalog by keyword",
  parameters: Schema.Struct({
    query: Schema.String,
    maxResults: Schema.Number.pipe(Schema.withDecodingDefault(() => 10)),
  }),
  success: Schema.Array(Product),
  failureMode: "error",
});

const GetInventory = Tool.make("GetInventory", {
  description: "Check current stock level for a product",
  parameters: Schema.Struct({ productId: ProductId }),
  success: Schema.Struct({ productId: ProductId, available: Schema.Number }),
});
```

### Create Toolkit

```ts
const ProductToolkit = Toolkit.make(SearchProducts, GetInventory);
```

### Implement Tool Handlers

```ts
const ProductToolkitLayer = ProductToolkit.toLayer(
  Effect.gen(function* () {
    yield* Effect.log("Initializing ProductToolkit");

    return ProductToolkit.of({
      SearchProducts: Effect.fn("SearchProducts")(function* ({
        query,
        maxResults,
      }) {
        // Search database or API
        return [
          new Product({
            id: ProductId.make("p-1"),
            name: `${query} widget`,
            price: 19.99,
          }),
        ].slice(0, maxResults);
      }),

      GetInventory: Effect.fn("GetInventory")(function* ({ productId }) {
        // Check inventory system
        return { productId, available: 42 };
      }),
    });
  }),
);
```

### Use Tools with Generation

```ts
const answerWithTools = Effect.fn("answerWithTools")(
  function* (question: string) {
    const toolkit = yield* ProductToolkit;

    const response = yield* LanguageModel.generateText({
      prompt: question,
      toolkit,
      toolChoice: "required", // Force tool use
    });

    // Inspect tool calls
    for (const call of response.toolCalls) {
      yield* Effect.log(`Tool call: ${call.name} id=${call.id}`);
    }

    // Inspect results
    for (const result of response.toolResults) {
      yield* Effect.log(
        `Tool result: ${result.name} id=${result.id} isFailure=${result.isFailure}`,
      );
    }

    return {
      text: response.text,
      toolCallCount: response.toolCalls.length,
    };
  },
  Effect.provide(modelLayer),
  Effect.provide(ProductToolkitLayer),
);
```

## Chat Sessions

### Basic Chat

```ts
import { Chat, Prompt } from "effect/unstable/ai";

const chatExample = Effect.gen(function* () {
  // Create chat with system prompt
  const session = yield* Chat.fromPrompt(
    Prompt.empty.pipe(
      Prompt.setSystem("You are a helpful assistant that answers questions."),
    ),
  );

  // Generate response
  const response1 = yield* session.generateText({
    prompt: "What is Effect?",
  });

  // Continue conversation (history maintained automatically)
  const response2 = yield* session.generateText({
    prompt: "How does it compare to RxJS?",
  });

  // Check conversation history
  const history = yield* Ref.get(session.history);
  yield* Effect.logInfo(`Conversation has ${history.content.length} messages`);
});
```

### Chat with Tools (Agentic)

```ts
const agentExample = Effect.gen(function* () {
  const tools = yield* ProductToolkit;
  const model = yield* OpenAiLanguageModel.model("gpt-5.2");

  // Start agent with system prompt
  const session = yield* Chat.fromPrompt([
    { role: "system", content: "You are an assistant that can use tools." },
    { role: "user", content: "What products do you have?" },
  ]);

  // Agent loop
  while (true) {
    const response = yield* session
      .generateText({
        prompt: [], // No additional prompt - model has conversation history
        toolkit: tools,
      })
      .pipe(Effect.provide(model));

    if (response.toolCalls.length === 0) {
      // No tool calls - model returned final answer
      return response.text;
    }

    // Tool calls executed automatically, loop continues
  }
});
```

## Provider-Defined Tools

### Using Built-in Tools

```ts
import { OpenAiTool } from "@effect/ai-openai";

// OpenAI web search
const webSearch = OpenAiTool.WebSearch({
  search_context_size: "medium",
});

// Combine with custom tools
const AssistantToolkit = Toolkit.make(
  SearchProducts,
  GetInventory,
  webSearch, // Provider-defined, no handler needed
);
```

## Best Practices

1. **Define custom error types** for AI operations
2. **Use ExecutionPlan** for provider fallback strategies
3. **Implement tool handlers** with proper error handling
4. **Log token usage** for cost monitoring
5. **Use streaming** for long responses to improve UX
6. **Validate generated objects** with Schema
7. **Handle rate limits** with retry schedules

## Testing AI Services

```ts
import { assert, describe, it } from "@effect/vitest";

describe("AiWriter", () => {
  it.effect("generates text", () =>
    Effect.gen(function* () {
      const writer = yield* AiWriter;
      const result = yield* writer.draftAnnouncement("Test Product");

      assert.isString(result);
      assert.isTrue(result.length > 0);
    }).pipe(Effect.provide(AiWriter.layer)),
  );
});
```

## Common Patterns

### Retry with Backoff

```ts
const resilientGeneration = operation.pipe(
  Effect.retry({
    schedule: Schedule.exponential("1 second"),
    while: (error) =>
      error._tag === "AiError" && error.reason._tag === "RateLimitError",
  }),
);
```

### Caching Responses

```ts
const cachedGeneration = Effect.cached(generateText(prompt), "1 hour");
```

### Parallel Generation

```ts
const parallelGeneration = Effect.forEach(
  prompts,
  (prompt) => generateText(prompt),
  { concurrency: 3 },
);
```
