# AI apps

This guide shows how to stream a message with the Web API. Slack shows the text while the app writes it. See the Slack references for [`chat.startStream`](https://docs.slack.dev/reference/methods/chat.startStream), [`chat.appendStream`](https://docs.slack.dev/reference/methods/chat.appendStream), and [`chat.stopStream`](https://docs.slack.dev/reference/methods/chat.stopStream). All three need the `chat:write` scope.

## Stream a message

A stream has three steps:

1. `Client#start_stream` sends `chat.startStream` and returns a `Slack::Api::MessageStream`.
2. `MessageStream#append` sends `chat.appendStream`. Call it as many times as necessary.
3. `MessageStream#stop` sends `chat.stopStream` and returns the final message.

```crystal
client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])

stream = client.start_stream(Slack::Api::ChatStartStream.new(
  channel: "C123", thread_ts: "1721609600.000001",
  recipient_user_id: "U123", recipient_team_id: "T123",
  markdown_text: "Checking the report."))

stream.append(client, markdown_text: " Revenue grew 4%.")

stream.stop(client,
  blocks: [Slack::UI::Blocks::Section.new(text: Slack::UI.mrkdwn("Was this helpful?"))],
  session_status: Slack::Api::Streaming::SessionStatus::Closed)
```

Each method makes one Web API call. The stream does not keep text in a buffer, start fibers, use timers, or stop itself. Always call `stop` when the answer is complete.

Rules for `ChatStartStream`:

- In a channel, Slack requires `recipient_user_id` and `recipient_team_id`. Give both or neither.
- Omit `thread_ts` to stream a top-level message. Slack accepts this only in some channels and returns `invalid_thread_ts` in other channels. Slack's `"0"` has the same meaning; use `nil`.
- `task_display_mode` is `Timeline` (Slack's default) or `Plan`.

`icon_emoji`, `icon_url` (start) and `metadata` (stop) are not available yet. They will use the shared message icon and metadata types.

## Content: text or chunks

Each request takes `markdown_text:` or `chunks:`. Slack does not accept both, so no constructor accepts both. `markdown_text` has 1 to 12,000 characters. `chunks` must not be empty. `chat.appendStream` needs one of the two; start and stop can have no content.

The content mode belongs to the stream. If you start the stream with `markdown_text`, append and stop with `markdown_text`. If you start it with `chunks`, append and stop with `chunks`. Slack returns `streaming_mode_mismatch` for a different mode. The library does not track the mode.

| Chunk | Wire type | Fields |
| --- | --- | --- |
| `Streaming::MarkdownTextChunk` | `markdown_text` | `text` |
| `Streaming::TaskUpdateChunk` | `task_update` | `id`, `title` (up to 256 characters), `status`, optional `hide_title`, `icon`, `details`, `output`, `sources` |
| `Streaming::PlanUpdateChunk` | `plan_update` | `title` (up to 256 characters) |
| `Streaming::BlocksChunk` | `blocks` | 1 to 50 message blocks |

To send task or plan updates, start the stream with chunks:

```crystal
stream = client.start_stream(Slack::Api::ChatStartStream.new(
  channel: "D123", task_display_mode: Slack::Api::Streaming::TaskDisplayMode::Plan,
  chunks: [Slack::Api::Streaming::MarkdownTextChunk.new("Checking the report.")]))

stream.append(client, chunks: [
  Slack::Api::Streaming::PlanUpdateChunk.new("Answer the question"),
  Slack::Api::Streaming::TaskUpdateChunk.new(id: "read", title: "Read the report",
    status: Slack::UI::TaskStatus::Complete,
    sources: [Slack::UI::BlockElements::UrlSource.new(url: "https://example.com/q3", text: "Q3 report")]),
])
```

A later task update with the same `id` changes that task. Chunk constructors validate their values and raise `Slack::UI::ValidationError`.

Notes on the chunk schema:

- `UI::TaskStatus::Pending` comes from the Slack Python SDK. The Slack reference lists only `in_progress`, `complete`, and `error`.
- `Streaming::IconRef` is undocumented. The only Slack example is `{"type":"icon","name":"https://…"}`, which is not the Slack icon object. The library sends the name without a check.
- Slack gives a 256-character limit for task and plan updates. The library checks it on titles only.

## Stop blocks and session status

`chat.stopStream` shows `blocks:` after the final message. They use the message block rules, at most 50 blocks, separate from any `BlocksChunk`. `session_status:` is `Active` (Slack's default), `Processing`, `Suspended`, or `Closed`.

## Errors

Slack failures raise `Slack::Api::Error` with the Slack code, for example `message_not_in_streaming_state`, `message_not_owned_by_app`, or `streaming_mode_mismatch`. Local validation runs before the request, so an invalid request never reaches Slack.

Offline examples and specs do not prove that Slack accepts or shows a stream. Slack checks the channel, thread, permissions, and streaming state. See [examples/streaming.cr](../examples/streaming.cr).
