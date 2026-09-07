# Agent Guidelines

Follow these guidelines when working on this Crystal project.

## Best Practices

- Favor explicit type signatures over implicit types.
- Use compile-time type checking as much as possible.
- Use `#as` casts only when absolutely necessary.
- Handle nil cases with `#try` or proper nil checks.
- Use unions, such as `String | Nil`, instead of loose typing.

## Concurrency

- Use fibers for concurrent operations, not threads.
- Properly close channels when done.
- Use `select` for channel multiplexing.
- Document fiber lifecycle and synchronization.
- Avoid race conditions with proper mutex usage.

## Project Documentation

- Be concise and clear.
- Organize the README into separate, focused sections. Avoid lengthy, unreadable documentation.
- Use examples liberally to illustrate concepts.
- Use ASD-STE100 Simplified Technical English to produce documentation that is readable by humans.

## Commit Messages and Pull Requests

- Make commit subjects, commit messages, PR titles, and PR descriptions meaningful on their own. Readers should not need the conversation or task history to understand them.
- Describe what changes and the impact of the change in clear, human-readable language.
- Do not use prefixes such as `fix:`, `feat:`, or `docs:`. Use a descriptive subject or title instead.
