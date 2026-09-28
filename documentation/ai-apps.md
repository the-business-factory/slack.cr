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

`ChatStartStream` takes `icon:` (`UI::Icon::Emoji` or `UI::Icon::Url`) and `username:`. `ChatStopStream` and `MessageStream#stop` take `metadata:` (`UI::MessageMetadata`).

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

## Show a plan with task cards

`Blocks::TaskCard` shows one task: its status, optional `details` and `output` as `Blocks::RichText`, and optional `sources`. `Blocks::Plan` shows a title and 1 to 50 task cards. Use them to keep the finished tasks in the message, for example as the `blocks:` of `MessageStream#stop` after a stream in plan mode:

```crystal
build_log = Slack::UI::BlockElements::UrlSource.new(url: "https://ci.example.com/builds/812", text: "Build 812")
checks = Slack::UI::Blocks::RichText.new(elements: {
  Slack::UI::RichText::Section.new(elements: {Slack::UI::RichText::Text.new("12 checks passed")}),
})
plan = Slack::UI::Blocks::Plan.new(title: "Check the deploy", block_id: "deploy.plan", tasks: {
  Slack::UI::Blocks::TaskCard.new(task_id: "build", title: "Read the build log",
    status: Slack::UI::TaskStatus::Complete, sources: [build_log]),
  Slack::UI::Blocks::TaskCard.new(task_id: "smoke", title: "Run the smoke tests",
    status: Slack::UI::TaskStatus::Complete, output: checks),
})

stream.stop(client, chunks: [Slack::Api::Streaming::MarkdownTextChunk.new("The deploy is healthy.")],
  blocks: [plan], session_status: Slack::Api::Streaming::SessionStatus::Closed)
# "blocks":[{"type":"plan","title":"Check the deploy","tasks":[
#   {"type":"task_card","task_id":"build","title":"Read the build log","status":"complete",
#    "sources":[{"type":"url","url":"https://ci.example.com/builds/812","text":"Build 812"}]},
#   {"type":"task_card","task_id":"smoke",...,"output":{"type":"rich_text",...}}],"block_id":"deploy.plan"}]
```

`MessageBuilder#plan(title:, tasks:, block_id:)` adds a plan to a message. A task card can also be a direct message block. Rules:

- Slack shows plans and task cards in messages only. `DisplayModal`, `FormModal`, `Home`, and `Blocks::Container` reject them at compile time.
- `task_id` and `title` must not be empty. Task IDs must be unique in a plan. `block_id` has at most 255 characters. Slack asks for a new `block_id` each time you update the message.
- Slack gives no length limit for `task_id`, `title`, or `sources`, so the library does not check one.
- `hide_title: true` hides the title; `details` then shows first. Slack still requires the title.

Differences between the Slack reference and the Slack SDKs:

- The plan reference calls its tasks "task-like objects without a type". The Slack SDK examples send task card blocks, so the library sends each task with `"type": "task_card"`.
- The task card `icon` field has no schema, so the library does not send it.
- `UI::TaskStatus::Pending` comes from the Slack SDKs and from the plan reference example. The task card reference lists only `in_progress`, `complete`, and `error`.

Received blocks decode as `Slack::Interactions::ReceivedBlocks::Plan` (`title`, `block_id`, and raw `tasks`) and `ReceivedBlocks::TaskCard` (`task_id`, `title`, `status` as a string, and `block_id`; read other fields from `raw`). See [Read blocks from messages and views](block-kit.md#read-blocks-from-messages-and-views). Offline examples do not prove that Slack shows these blocks outside a stream. See Slack's [plan block](https://docs.slack.dev/reference/block-kit/blocks/plan-block) and [task card block](https://docs.slack.dev/reference/block-kit/blocks/task-card-block) references and [examples/plan.cr](../examples/plan.cr).

## Errors

Slack failures raise `Slack::Api::Error` with the Slack code, for example `message_not_in_streaming_state`, `message_not_owned_by_app`, or `streaming_mode_mismatch`. Local validation runs before the request, so an invalid request never reaches Slack.

Offline examples and specs do not prove that Slack accepts or shows a stream. Slack checks the channel, thread, permissions, and streaming state. See [examples/streaming.cr](../examples/streaming.cr).

## App threads

An app thread is the conversation between a user and the app in the app's split view. Three requests change what the user sees in the thread. Send each one with `Client#call`; each returns `Models::DefaultResponse`.

```crystal
client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])

client.call(Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: "D123",
  title: "Try one of these",
  prompts: [Slack::Api::SuggestedPrompt.new(title: "Summarize", message: "Summarize this channel.")]))

client.call(Slack::Api::AssistantThreadsSetTitle.new(channel_id: "D123",
  thread_ts: "1724264405.531769", title: "Weekly summary"))

client.call(Slack::Api::AssistantThreadsSetStatus.new(channel_id: "D123",
  thread_ts: "1724264405.531769", status: "is thinking...",
  loading_messages: ["Reading the channel", "Writing the summary"]))
```

| Request | Slack method | Scope | Rules |
| --- | --- | --- | --- |
| `AssistantThreadsSetStatus` | `assistant.threads.setStatus` | `assistant:write` or `chat:write` | `thread_ts` is required. `loading_messages` has 1 to 10 messages. `icon` (`UI::Icon::Emoji` or `UI::Icon::Url`) and `username` need `chat:write.customize`. |
| `AssistantThreadsSetSuggestedPrompts` | `assistant.threads.setSuggestedPrompts` | `assistant:write` | 1 to 4 prompts. Each `SuggestedPrompt` has a `title` and a `message`, which must not be blank. `title` of the list is optional. |
| `AssistantThreadsSetTitle` | `assistant.threads.setTitle` | `assistant:write` | `title` must not be blank. |

Notes:

- To clear the status, send an empty `status`. Slack also removes the status after two minutes if the app sends no message.
- Omit `thread_ts` on `AssistantThreadsSetSuggestedPrompts` to set prompts for the latest message in the channel. Slack says `thread_ts` is for the legacy assistant experience. With an agent app, a call with `thread_ts` fails silently.
- The library does not send a status, title, or prompts automatically. It does not start timers or fibers.

See [examples/assistant_thread.cr](../examples/assistant_thread.cr).

## Agent sessions

Slack names `agents.sessions.setStatus` as the successor of `assistant.threads.setStatus`, and `agents.sessions.rename` as the successor of `assistant.threads.setTitle`. Both need the `chat:write` scope and a bot token.

```crystal
session = client.call(Slack::Api::AgentsSessionsSetStatus.new(
  status: Slack::Api::Streaming::SessionStatus::Processing,
  channel_id: "C123", thread_ts: "1234567890.123456", title: "Scuba diving research"))
session.status       # => "processing" (status of the session for all agents)
session.agent_status # => "processing" (status of this agent)

renamed = client.call(Slack::Api::AgentsSessionsRename.new(title: "Bora Bora trip prep",
  channel_id: "C123", thread_ts: "1234567890.123456"))
renamed.title # => "Bora Bora trip prep"
```

- `status` is `Active`, `Processing`, `Suspended`, or `Closed`. It uses the same `Streaming::SessionStatus` enum as `chat.stopStream`. Set `Active` to clear a loading indicator.
- Slack creates the session if necessary. `title` (up to 200 characters) and `initiator_user_id` apply only when Slack creates the session.
- `AgentsSessionsRename` needs a `title` of 1 to 200 characters. For a session channel, Slack also renames the channel.
- Slack requires `channel_id` for public channels and `thread_ts` for thread sessions in regular channels and DMs. Omit `thread_ts` for a session channel. Slack checks these rules; the library does not.
- The response fields `status` and `agent_status` are strings, so a new Slack status value does not make a successful call fail.

Offline specs do not prove that Slack accepts or shows a status, prompts, or a title. Slack checks the channel, thread, app type, and permissions.
