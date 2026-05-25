# Skill Evaluation Examples

Use these scenarios to test the effectiveness of the building-with-effect skill. Each evaluation includes a task description and expected behavior criteria.

## Evaluation 1: Creating a User Service

**Task**: Create a complete UserService using Effect.fn and Schema.TaggedErrorClass that can fetch users from a database with proper error handling.

**Expected Behavior**:

- [ ] Defines UserNotFoundError and DatabaseError using Schema.TaggedErrorClass with descriptive \_tag fields
- [ ] Creates UserService class extending Context.Service with proper type annotations
- [ ] Implements fetchUser method using Effect.fn with tracing span
- [ ] Handles errors appropriately with catchTags for specific error types
- [ ] Builds a Layer.effect with the service implementation
- [ ] Provides proper dependency injection via Layer.provide
- [ ] Uses Effect.try or Effect.tryPromise for external API calls
- [ ] Returns errors properly with `return yield* new ErrorType()` pattern

**Example Solution Pattern**:

```ts
class UserNotFoundError extends Schema.TaggedErrorClass<UserNotFoundError>()(
  "UserNotFoundError",
  { userId: Schema.String },
) {}

class DatabaseError extends Schema.TaggedErrorClass<DatabaseError>()(
  "DatabaseError",
  { cause: Schema.Defect },
) {}

export class UserService extends Context.Service<
  UserService,
  {
    fetchUser: (
      id: string,
    ) => Effect.Effect<User, UserNotFoundError | DatabaseError>;
  }
>()("app/UserService") {
  static readonly layer = Layer.effect(
    UserService,
    Effect.gen(function* () {
      const fetchUser = Effect.fn("UserService.fetchUser")(function* (
        id: string,
      ) {
        // Implementation with proper error handling
      }, Effect.withSpan("UserService.fetchUser"));
      return UserService.of({ fetchUser });
    }),
  );
}
```

## Evaluation 2: Error Handling with Multiple Error Types

**Task**: Implement a function that calls an external API and handles three different error scenarios: network errors, parsing errors, and validation errors. Use catchTags for specific handling.

**Expected Behavior**:

- [ ] Defines three distinct error types with Schema.TaggedErrorClass
- [ ] Uses Effect.tryPromise for the API call with proper error mapping
- [ ] Implements catchTags with separate handlers for each error type
- [ ] Provides appropriate fallback values or recovery strategies
- [ ] Uses Effect.mapError to transform errors at service boundaries
- [ ] Logs errors at appropriate levels (logError, logWarning)
- [ ] Returns meaningful error messages with context (e.g., request ID, timestamp)

**Example Solution Pattern**:

```ts
class NetworkError extends Schema.TaggedErrorClass<NetworkError>()(
  "NetworkError",
  { statusCode: Schema.Number },
) {}

class ParseError extends Schema.TaggedErrorClass<ParseError>()(
  "ParseError",
  { input: Schema.String, message: Schema.String },
) {}

class ValidationError extends Schema.TaggedErrorClass<ValidationError>()(
  "ValidationError",
  { field: Schema.String, message: Schema.String },
) {}

const fetchData = Effect.fn("fetchData")(function* (url: string) {
  // API call implementation
});

const resilientFetch = (url: string) =>
  fetchData(url).pipe(
    Effect.catchTags({
      NetworkError: (e) => Effect.succeed(cachedData),
      ParseError: (e) => Effect.fail(new ValidationError({ ... })),
      ValidationError: (e) => Effect.succeed(defaultValue),
    }),
  );
```

## Evaluation 3: AI Integration with ExecutionPlan

**Task**: Set up an AI service that can generate text with automatic fallback between OpenAI and Anthropic providers using ExecutionPlan.

**Expected Behavior**:

- [ ] Installs and imports correct provider packages (@effect/ai-openai, @effect/ai-anthropic)
- [ ] Configures client layers with Config.redacted for API keys
- [ ] Defines ExecutionPlan with multiple providers and attempt counts
- [ ] Creates AI service class extending Context.Service
- [ ] Implements generation method using Effect.fn
- [ ] Uses Effect.withExecutionPlan to apply the fallback strategy
- [ ] Maps AI errors to domain-specific error types
- [ ] Provides both client layers to the service layer via Layer.provide
- [ ] Includes proper error handling for rate limits and quota exceeded
- [ ] Uses AiError.AiErrorReason for error reasons
- [ ] Implements fromAiError static method
- [ ] Returns provider info alongside generated text

**Example Solution Pattern**:

```ts
import { AiError } from "effect/unstable/ai"

class AiGenerationError extends Schema.TaggedErrorClass<AiGenerationError>()(
  "AiGenerationError",
  { reason: AiError.AiErrorReason }
) {
  static fromAiError(error: AiError.AiError) {
    return new AiGenerationError({ reason: error.reason })
  }
}

export class AiService extends Context.Service<
  AiService,
  {
    generate: (prompt: string) => Effect.Effect<
      { readonly provider: string; readonly text: string },
      AiGenerationError
    >;
  }
>()("app/AiService") {
  static readonly layer = Layer.effect(
    AiService,
    Effect.gen(function* () {
      const FallbackPlan = ExecutionPlan.make(
        { provide: OpenAiLanguageModel.model("gpt-5.2"), attempts: 3 },
        { provide: AnthropicLanguageModel.model("claude-opus-4-6"), attempts: 2 }
      )

      const draftsModel = yield* FallbackPlan.withRequirements

      const generate = Effect.fn("AiService.generate")(
        function* (prompt: string) {
          const response = yield* LanguageModel.generateText({ prompt })
          return { provider: response.provider, text: response.text }
        },
        Effect.withExecutionPlan(draftsModel),
        Effect.mapError((error) => AiGenerationError.fromAiError(error))
      )

      return AiService.of({ generate })
    }),
  ).pipe(Layer.provide([OpenAiClientLayer, AnthropicClientLayer]))
}
```

See working example: [ai-docs/src/71_ai/10_language-model.ts](https://github.com/Effect-TS/effect-smol/blob/main/ai-docs/src/71_ai/10_language-model.ts)

## Testing Your Usage

When using this skill, verify it helps you:

1. **Select appropriate patterns**: Does Claude recommend Effect.fn for new functions?
2. **Handle errors correctly**: Are errors defined with Schema.TaggedErrorClass?
3. **Structure services properly**: Are services created with Context.Service?
4. **Use workflows**: Does Claude suggest workflow checklists for complex tasks?
5. **Follow degrees of freedom**: Does Claude know when to be strict vs flexible?

If Claude misses any of these, the skill may need refinement.
