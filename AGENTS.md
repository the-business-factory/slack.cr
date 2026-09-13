# Agent Guidelines

Follow these guidelines when working on this Crystal project.
Use the Crystal 1.21 [coding style](https://crystal-lang.org/reference/1.21/conventions/coding_style.html), [code documentation](https://crystal-lang.org/reference/1.21/syntax_and_semantics/documenting_code.html), and [testing](https://crystal-lang.org/reference/1.21/guides/testing.html) guides as references.

## Best Practices

- Favor explicit type signatures over implicit types.
- Use compile-time type checking as much as possible.
- Use `#as` casts only when absolutely necessary.
- Handle nil cases with `#try` or proper nil checks.
- Bind a nilable getter to a local variable before checking and using it. Repeated getter calls do not retain type narrowing.
- Use unions, such as `String | Nil`, instead of loose typing.
- Prefer standard library methods for collection and parameter handling, such as `URI::Params#fetch_all`. Preserve duplicate-field validation.

## Code Organization

- Prefer one class or struct per file, with a filename that matches the type. Keep small, tightly related value types together only when this improves readability.
- Give each type one clear responsibility. Separate parsing, storage, HTTP transport, and application flow at their natural boundaries.
- Use clear names and short, focused methods so code explains its purpose. Add comments for constraints and decisions that the code cannot express.
- Use guard clauses and named steps to reduce nesting. Combine case branches that perform the same operation.
- Implement the current requirements. Avoid speculative abstractions, extension points, and configuration.
- Preserve validation and side-effect order during refactors. For example, verify webhook bytes before parsing or storage access, and consume valid OAuth state before checking denial or code fields.
- Make resource ownership clear when extracting code. State who closes an IO on success and failure, and preserve transport error classification before and after application writes.

## Testing

- Keep test support small and specific. Separate reusable helpers from executable subprocess fixtures.
- Test observable behavior, regressions, and important failure modes. Avoid tests that repeat implementation details or only exercise trivial wiring.
- Prefer ecosystem tools over custom test infrastructure. Keep tests offline by default and use synthetic credentials.
- Run `crystal tool format` on changed Crystal files and verify formatting with `crystal tool format --check`.
- After a refactor, run the relevant specs and Ameba in addition to formatting checks.
- When changing public types or accessors, compile representative existing consumer code. Document intentional breaking changes and migration steps.
- Give concurrent Crystal test runs separate `CRYSTAL_CACHE_DIR` directories. Shared temporary executables can be replaced or removed by another run. Delete only cache directories owned by that run.

## Concurrency

- Use fibers for concurrent operations, not threads.
- Properly close channels when done.
- Use `select` for channel multiplexing.
- Document fiber lifecycle and synchronization.
- Avoid race conditions with proper mutex usage.

## Project Documentation

- Be concise and clear.
- Put `# :nodoc:` first in the doc comment for internal helper types that are not supported public APIs.
- Organize the README into separate, focused sections. Avoid lengthy, unreadable documentation.
- Use examples liberally to illustrate concepts.
- Use ASD-STE100 Simplified Technical English to produce documentation that is readable by humans.

## Commit Messages and Pull Requests

- Make commit subjects, commit messages, PR titles, and PR descriptions meaningful on their own. Readers should not need the conversation or task history to understand them.
- Describe what changes and the impact of the change in clear, human-readable language.
- Do not use prefixes such as `fix:`, `feat:`, or `docs:`. Use a descriptive subject or title instead.
