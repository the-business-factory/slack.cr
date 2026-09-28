# slack.cr

Crystal client for Slack Web API calls, signed requests, OAuth app installation, and Block Kit. Requires Crystal 1.21.0 or later.

## Installation

Add the shard to `shard.yml`:

```yaml
dependencies:
  slack:
    github: the-business-factory/slack.cr
```

Run `shards install` and use the full library with `require "slack"`.

## Web API quickstart

Create one `Slack::Api::Client` with a token. Send typed requests with `call`. The token must have the scope that each Slack method requires. For example, a bot token with `team:read` can request team information:

```crystal
require "slack"

client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])
team = client.call(Slack::Api::TeamInfo.new)
puts team.name
```

A method without a typed request is available through the generic call. It sends form fields and returns the raw JSON. Strings are sent unchanged; other values are sent as JSON text:

```crystal
dnd = client.call("dnd.info", {user: "U123"})
dnd["snooze_enabled"].as_bool
```

An unsuccessful result raises `Slack::Api::Error`. `code` is Slack's error name, such as `channel_not_found`, `messages` holds `response_metadata.messages`, and `details` holds problems from a top-level `errors` array, such as the manifest problems of `invalid_manifest`. HTTP 429 raises `Slack::Api::RateLimited`, with `retry_after` from the `Retry-After` header. The error message never contains the response body, headers, or token.

The client paces each method locally at its documented [rate limit tier](https://docs.slack.dev/apis/web-api/rate-limits) and makes exactly one attempt. It does not retry. Local pacing does not guarantee that Slack accepts the call. API calls use `https://slack.com/api/` by default. Pass `configuration:` and `transport:` to the client to change this; see [authentication and transport](documentation/authentication.md).

To upload a file or share a remote file, see [files](documentation/files.md). `Slack::Api::FileUpload` runs the three-step upload flow and keeps the file in memory.

| Feature | Credentials and setup |
| --- | --- |
| Build or inspect Block Kit values | None. |
| Direct Web API request | Token with the method's required scopes. |
| Signed Events API, command, or interaction HTTP request | App signing secret in a `Slack::Webhooks::Verifier`. A valid timestamp prevents stale requests; the application handles duplicate deliveries. |
| OAuth app installation | Client ID, client secret, redirect URI, bot/user scopes, trusted session binding, state store, and application-owned installation store. Pass scopes to `AuthHandler`. |
| Stored credential dispatch and rotation | Installation store; rotating grants also need the OAuth token endpoint and client credentials. |

The library has no global settings and reads no environment variables. Give each credential to the object that uses it: the signing secret to `Slack::Webhooks::Verifier`, a token to `Slack::Api::Client`, and a `Slack::Auth::OAuthConfiguration` to `AuthHandler`. [Authentication](documentation/authentication.md) covers installation, request authorization, rotation, revocation, storage, and transport.

### Read all pages

List methods return one page at a time. `each_page` sends a paginated request, yields each `Slack::Api::Page`, and sends the request again with the page's `next_cursor`. It stops when Slack returns an empty, null, or missing cursor. Break from the block to stop early:

```crystal
request = Slack::Api::ConversationsList.new(
  types: [Slack::Api::ConversationType::PublicChannel, Slack::Api::ConversationType::PrivateChannel],
  exclude_archived: true, limit: 200)
client.each_page(request) do |page|
  page.model.channels.each { |channel| puts channel.id }
end
```

Paginated requests are `ConversationsList`, `ConversationsHistory`, `ConversationsReplies`, `ConversationsMembers`, `UsersList`, `UsersConversations`, `AuthTeamsList`, and `ReactionsList`. Each accepts `cursor:` and `limit:`. The client rejects a `limit` outside 1 to 1000 before it sends the request; Slack checks lower method maximums. Slack recommends 100 to 200 items per page. `ConversationsInfo` reads one conversation, with optional `include_locale:` and `include_num_members:`. Conversations read as `PublicChannel`, `PrivateChannel` (also group direct messages), or `IMChat`.

Each page is one call: local pacing applies, and an error such as `RateLimited` raises from the loop. The client does not wait and retry. Since 2025-05-29, Slack limits `conversations.history` and `conversations.replies` to one request per minute and 15 items per page for new apps distributed outside the Slack Marketplace. The client does not enforce this limit. See [pagination](https://docs.slack.dev/apis/web-api/pagination) and [rate limits](https://docs.slack.dev/apis/web-api/rate-limits).

### Users and user groups

Read people and bots with `UsersInfo`, `UsersLookupByEmail`, `UsersList`, and `BotsInfo`. A `Slack::Models::User` has `id`, `team_id`, `name`, `real_name`, `tz`, the flags `deleted?`, `is_bot?`, `is_admin?`, and `is_owner?`, and a `profile`. Slack omits empty profile fields, and `email` needs the `users:read.email` scope:

```crystal
user = client.call(Slack::Api::UsersLookupByEmail.new("ana@example.test")).user
puts "#{user.profile.display_name} #{user.tz}"
```

`UsersConversations` reads the conversations of a user. `UsersProfileGet`, `UsersGetPresence`, and `UsersSetPresence` read and set the profile and presence. `UsersProfileSet` sets several fields with `profile:`, or one field with `name:` and `value:`; it needs a user token:

```crystal
client.call(Slack::Api::UsersProfileSet.new(profile: {status_text: "Focus time", status_emoji: ":headphones:"}))
```

User groups use `UsergroupsList`, `UsergroupsCreate`, `UsergroupsUpdate`, `UsergroupsEnable`, `UsergroupsDisable`, `UsergroupsUsersList`, and `UsergroupsUsersUpdate`. `UsergroupsUsersUpdate` replaces all members and needs at least one user ID:

```crystal
group = client.call(Slack::Api::UsergroupsCreate.new("On-call", handle: "oncall")).usergroup
client.call(Slack::Api::UsergroupsUsersUpdate.new(group.id, ["U1", "U3"]))
```

`TeamInfo` reads the token's workspace, or another workspace with `team:` or `domain:`. Slack checks name and handle uniqueness, scopes, and admin permissions.

### Reactions, pins, and bookmarks

`ReactionsAdd` and `ReactionsRemove` add and remove an emoji reaction. `ReactionsGet` reads the reactions of one message or file, and `ReactionsList` reads the items that a user reacted to, page by page. Give a message with `channel:` and `timestamp:`, or a file with `file:`. Slack answers `already_reacted` or `no_reaction` when the reaction is already there or is missing:

```crystal
begin
  client.call(Slack::Api::ReactionsAdd.new(channel: "C123", name: "eyes", timestamp: ts))
rescue error : Slack::Api::Error
  raise error unless error.code == "already_reacted"
end
item = client.call(Slack::Api::ReactionsGet.new(channel: "C123", timestamp: ts, full: true))
(item.message.try(&.reactions) || [] of Slack::Models::Reaction).each do |reaction|
  puts "#{reaction.name} #{reaction.count}"
end
```

`PinsAdd`, `PinsRemove`, and `PinsList` pin, unpin, and list the messages of a channel. Slack answers `already_pinned` for a message that is already pinned. `BookmarksAdd`, `BookmarksEdit`, `BookmarksList`, and `BookmarksRemove` manage the link bookmarks of a channel. `BookmarksEdit` sends only the fields that you give:

```crystal
client.call(Slack::Api::PinsAdd.new("C123", ts))
bookmark = client.call(Slack::Api::BookmarksAdd.new("C123", "Runbook", "https://example.com/runbook", emoji: ":books:")).bookmark
client.call(Slack::Api::BookmarksEdit.new("C123", bookmark.id, title: "Queue runbook"))
```

The client rejects an empty reaction name, an empty bookmark title or link, and an edit without changes before it sends. Slack checks emoji names, links, scopes, and pin and bookmark limits.


### Manage conversations

Create, rename, archive, and restore channels with `ConversationsCreate`, `ConversationsRename`, `ConversationsArchive`, and `ConversationsUnarchive`. A name has at most 80 characters; Slack checks the allowed characters. Change membership with `ConversationsJoin`, `ConversationsLeave`, `ConversationsInvite` (1 to 1000 user IDs), and `ConversationsKick` (one user). `ConversationsSetTopic` and `ConversationsSetPurpose` accept at most 250 characters, and `ConversationsMark` moves the read cursor. Requests that change a channel return its `Slack::Models::Conversation`:

```crystal
channel = client.call(Slack::Api::ConversationsCreate.new("incident-42", is_private: true))
client.call(Slack::Api::ConversationsInvite.new(channel.id, ["U1", "U2"], force: true))
client.call(Slack::Api::ConversationsSetTopic.new(channel.id, "Checkout errors"))
```

Slack errors raise `Slack::Api::Error`. For example, `name_taken` means the name exists, `not_in_channel` means the caller is not a member, and `channel_not_found` means the ID is wrong or not visible to the token. When one invited user is not valid, Slack invites nobody and raises the first error; `force: true` invites the valid users.

`ConversationsOpen` opens a direct message with one user or a group direct message with two to eight users. It can also resume a conversation by `channel:`. `channel_id` returns the conversation ID. With `return_im: true`, `channel` is the full conversation: an `IMChat`, or a `PrivateChannel` for a group direct message:

```crystal
dm = client.call(Slack::Api::ConversationsOpen.new(users: ["U1"]))
client.call(Slack::Api::ChatPostMessage.new(channel: dm.channel_id, text: "You lead this incident."))
```

Shared channel invitations (`conversations.inviteShared` and related methods) use the generic call.

## Block Kit

Block Kit values validate supported fields and surface placement when built. Constructing them needs no credentials:

```crystal
require "slack"

alias UI = Slack::UI
message = UI.message(fallback_text: "Request 42 needs approval.") do |builder|
  builder.section(UI.mrkdwn("*Request 42* needs approval"))
  builder.actions(elements: [
    UI::BlockElements::Button.new(
      text: UI.plain("Approve"),
      action_id: "request.approve",
      value: "42",
      accessibility_label: "Approve request 42"
    ),
  ])
end

client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])
response = client.call(Slack::Api::ChatPostMessage.new(
  channel: ENV["SLACK_CHANNEL_ID"],
  message: message
))
```

The send requires a bot token with `chat:write` and a channel the app can post to. Use `message.to_pretty_json` to inspect the payload locally. See [Block Kit](documentation/block-kit.md) for supported blocks, messages, modals, Home, static choices, incoming actions, and validation.

## App listeners

`Slack::App` routes verified requests to typed listeners, as Bolt's `App` does. `Slack::App::HttpReceiver` is an `HTTP::Handler` that verifies, decodes, routes, and writes the acknowledgment.

```crystal
client = Slack::Api::Client.new(token: Slack::Auth::Secret.new(ENV["SLACK_BOT_TOKEN"]))
app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))

app.command("/deploy") do |ctx|
  ctx.ack(Slack::Commands::Response.new(text: "Deploying #{ctx.command.text}."))
end
app.action("deploy.approve") { |ctx| ctx.ack }

verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(ENV["SLACK_SIGNING_SECRET"]))
HTTP::Server.new([Slack::App::HttpReceiver.new(app, verifier)]).listen(3000)
```

The receiver answers when the listener calls `ack` or returns, or after 2.5 seconds. See [App listeners](documentation/app.md) for listeners, middleware, authorization, and responses.

## Events API payloads

Verify the signed request with `Slack::Webhooks::Verifier`, then give the verified body to `Slack::Events.parse`. It returns `Slack::UrlVerification`, `Slack::AppRateLimited`, or `Slack::VerifiedEvent`. The inner `event` is a typed struct for mapped types. An event type that the library does not map decodes as `Slack::Events::Unknown`: `type` gives the event type and `raw` keeps the complete event JSON. Match `Unknown` explicitly. Do not log `raw`: it can hold credentials, such as a workflow `bot_access_token`.

```crystal
verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(signing_secret))
envelope = Slack::Events.parse(verifier.verify(request).body)
if envelope.is_a?(Slack::VerifiedEvent)
  delivery = Slack::Events::Delivery.from_headers(request.headers)
  case event = envelope.event
  when Slack::Events::AppMentioned then reply(event)
  when Slack::Events::Unknown      then log("Skipped #{event.type} #{envelope.event_id}")
  end
  # delivery.retry_num (1 to 3) and delivery.retry_reason ("http_timeout", ...) are nil on the first delivery.
end
```

The envelope also gives `is_ext_shared_channel`, `context_team_id`, `context_enterprise_id`, and `event_context`. Each is nil when Slack omits it.

### Typed events

These inner event types decode as typed structs in `Slack::Events`:

| Group | Event types |
| --- | --- |
| App | `app_home_opened`, `app_mention`, `app_installed`, `app_deleted`, `app_requested`, `app_uninstalled`, `tokens_revoked`, `function_executed` |
| Channels and members | `channel_created`, `channel_deleted`, `channel_rename`, `channel_archive`, `channel_unarchive`, `member_joined_channel`, `member_left_channel`, `team_join` |
| Messages | `message`, `link_shared`, `message_metadata_posted`, `message_metadata_updated`, `message_metadata_deleted`, `pin_added`, `pin_removed`, `reaction_added`, `reaction_removed` |
| Users, groups, and emoji | `user_change`, `user_status_changed`, `subteam_created`, `subteam_updated`, `subteam_members_changed`, `subteam_self_added`, `subteam_self_removed`, `emoji_changed` |

User, user group, app request, and pinned item objects stay raw `JSON::Any`. Message metadata gives `event_type` and a raw `event_payload`.

A `message` event selects a struct in `Slack::Events::Message` by `subtype`: `bot_add`, `bot_message`, `channel_join`, `channel_leave`, `channel_name`, `channel_purpose`, `channel_topic`, `file_share`, `me_message`, `message_changed`, `message_deleted`, `message_replied`, `pinned_item`, `thread_broadcast`, and `unpinned_item`. A message without a subtype, or with a subtype that the library does not map, decodes as `Slack::Events::Message`; its `subtype` gives the name. `channel`, `user`, `team`, `text`, and `channel_type` are nil when Slack omits them. A typed subtype gives `channel`, `channel_type`, and `event_ts` as nil when Slack omits them, as several reference examples do. Slack documents that `message_replied` can arrive without its subtype, so check `thread_ts` to find replies. A canvas mention arrives as `app_mention` with `subtype` `document_mention` and a `document_mention` value.

```crystal
case event = envelope.event
when Slack::Events::LinkShared
  unfurl(event.channel, event.message_ts, event.links.map(&.url))
when Slack::Events::Message::ChannelTopic
  log("#{event.channel} topic: #{event.topic}")
when Slack::Events::Message
  log("Message subtype #{event.subtype}") if event.subtype
end
```

Slack sends `app_rate_limited` instead of events when the app would get more than 30,000 events in one hour from one workspace. It has no inner event. `Slack::AppRateLimited#minute_rate_limited` gives the minute when the limit started. Return HTTP 200 for it.

### Assistant and agent events

These events decode as typed structs in `Slack::Events`:

| Event type | Struct | Main values |
| --- | --- | --- |
| `assistant_thread_started` | `AssistantThreadStarted` | `assistant_thread` (`user_id`, `channel_id`, `thread_ts`, `context`) |
| `assistant_thread_context_changed` | `AssistantThreadContextChanged` | `assistant_thread` with the new `context` |
| `app_context_changed` | `AppContextChanged` | `context.entities` (`type`, `value`, `team_id`), most relevant first |
| `agent_session_stopped` | `AgentSessionStopped` | `channel`, `thread_ts`, `streaming_message_ts` |
| `agent_session_title_changed` | `AgentSessionTitleChanged` | `title`, `previous_title` |

`assistant_thread.context` is nil when Slack does not send it. Its `channel_id`, `team_id`, and `enterprise_id` are nil when Slack sends an empty context. Call `conversations.info` before you use `channel_id`, because the app can have no access to that channel.

The root message of an assistant thread has the subtype `assistant_app_thread`. It decodes as `Slack::Events::Message::AssistantAppThread`. Slack also sends this subtype inside other subtypes, such as the `message` of `message_changed`, so check `message.subtype` there:

```crystal
case event = envelope.event
when Slack::Events::AssistantThreadStarted
  thread = event.assistant_thread
  greet(thread.channel_id, thread.thread_ts, thread.context.try(&.channel_id))
when Slack::Events::AgentSessionStopped
  cancel_work(event.channel, event.thread_ts)
when Slack::Events::Message::MessageChanged
  store_title(event.message.assistant_app_thread.try(&.title)) if event.message.subtype == "assistant_app_thread"
end
```

The library does not call the assistant or agent session methods for these events, and Slack does not change a stopped session status by itself. The offline specs do not prove that Slack sends these events to an app.

### Retries

Slack retries a delivery up to three times when the app does not return HTTP 2xx within three seconds. To stop retries for a failed delivery, add `Slack::Events::Delivery::NO_RETRY_HEADER` with `NO_RETRY_VALUE` (`X-Slack-No-Retry: 1`) to the non-2xx response. The library does not send responses or remove duplicate deliveries; use `event_id` for that. The offline specs do not prove Slack retry timing or behavior.

## Socket Mode

Receive events, interactions, and slash commands over a WebSocket. The client gets the URL with an app-level token (`xapp-`), acknowledges through the `Acknowledger`, and reconnects when Slack refreshes the connection.

```crystal
require "slack"

client = Slack::SocketMode::Client.new(ENV["SLACK_APP_TOKEN"])
client.run do |envelope, ack|
  ack.ack
  puts envelope.command.text if envelope.kind.slash_commands?
end
```

To decode frames without a connection, use `Slack::SocketMode::Frame.parse` and `Slack::SocketMode::Acknowledgment`. See [Socket Mode](documentation/socket-mode.md) for the connection lifecycle, frame types, payload decoding, and acknowledgment payloads.

## Slash commands and response URLs

Verify a slash command, then answer it in the HTTP 200 body. Post later replies to its `response_url`.

```crystal
command = Slack::Commands.parse(verifier.verify(request).body)
body = Slack::Commands::Response.new(text: "Deploy started.").to_json
# {"response_type":"ephemeral","text":"Deploy started."}

later = Slack::Interactions::ResponseUrlMessage.new(text: "Deploy finished.", replace_original: true)
Slack::Interactions::ResponseUrlResponder.new(command.response_url).post(Slack::Auth::HTTPTransport.new, later)
```

A `response_url` accepts five posts within 30 minutes. See [Respond to a slash command](documentation/block-kit.md#respond-to-a-slash-command).

## Workflow steps

A custom function in the app manifest is a workflow step. When a workflow runs the step, Slack sends a `function_executed` event. Read the inputs, then complete or fail the execution with the event's `bot_access_token`:

```crystal
if (event = envelope.event).is_a?(Slack::Events::FunctionExecuted)
  client = Slack::Api::Client.new(token: event.bot_access_token)
  client.call(Slack::Api::FunctionsCompleteSuccess.new(
    function_execution_id: event.function_execution_id,
    outputs: {user_id: event.inputs["user_id"].as_s}))
end
```

See [Workflow steps](documentation/workflows.md) for the manifest, inputs, and failures.

## Streaming messages

`Client#start_stream` starts a streamed message; the returned `MessageStream` appends text or task chunks and stops it. `Blocks::Plan` and `Blocks::TaskCard` keep the finished tasks in the message. See [AI apps](documentation/ai-apps.md).

## App threads and agent sessions

`AssistantThreadsSetStatus`, `AssistantThreadsSetSuggestedPrompts`, and `AssistantThreadsSetTitle` show a status, suggested prompts, and a title in an app thread. `AgentsSessionsSetStatus` and `AgentsSessionsRename` change an agent session. See [AI apps](documentation/ai-apps.md#app-threads).

## Testing your app

Test handlers offline with `require "slack/testing"`. `require "slack"` does not load it.

- `Slack::Testing::SignedRequest.build` makes a POST request with a valid `X-Slack-Signature` and `X-Slack-Request-Timestamp`. `Webhooks::Verifier` accepts it with the same signing secret.
- `Slack::Testing::RecordingTransport` is a transport for `Slack::Api::Client`. It records each request and answers with the responses that you queue. A request without a response raises `Slack::Testing::UnstubbedRequest`.

```crystal
require "slack"
require "slack/testing"

secret = Slack::Auth::Secret.new("synthetic-signing-secret")
request = Slack::Testing::SignedRequest.build(form_body, signing_secret: secret,
  path: "/slack/commands", content_type: "application/x-www-form-urlencoded")

transport = Slack::Testing::RecordingTransport.new
transport.respond(%({"ok":true,"channel":"C123","ts":"1710000000.000100","message":{"type":"message","ts":"1710000000.000100"}}))
client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: transport)

handler.handle(request) # your code verifies the request and calls client
transport.requests.first.uri.path # => "/api/chat.postMessage"
transport.requests.first.body     # => %({"channel":"C123","text":"..."})
```

Queued responses are used in order. To compute answers, give a block to `RecordingTransport.new`; the block answers when the queue is empty. Recorded requests contain the token, so use synthetic credentials. These tools do not prove that Slack accepts a request.

## Runnable examples

From a repository checkout, run `shards install` first. The modal, Home, and static choice examples use the development dependency WebMock. They use synthetic credentials and stub HTTP requests; they do not contact Slack.

```sh
crystal run examples/block_kit_message.cr
crystal run examples/block_kit_modal.cr
crystal run examples/block_kit_home.cr
crystal run examples/block_kit_static_select.cr
crystal run examples/block_kit_overflow.cr
crystal run examples/block_kit_checkboxes.cr
crystal run examples/block_kit_radio_buttons.cr
crystal run examples/block_kit_message_update.cr
crystal run examples/block_kit_view_update.cr
crystal run examples/block_kit_users_select.cr
crystal run examples/block_kit_view_push.cr
crystal run examples/block_kit_modal_errors.cr
crystal run examples/block_kit_modal_clear.cr
crystal run examples/block_kit_channels_select.cr
crystal run examples/block_kit_modal_push.cr
crystal run examples/block_kit_modal_update.cr
crystal run examples/block_kit_conversations_select.cr
crystal run examples/block_kit_date_time_pickers.cr
crystal run examples/block_kit_datetime_picker.cr
crystal run examples/block_kit_video.cr
crystal run examples/block_kit_external_select.cr
crystal run examples/block_kit_rich_text.cr
crystal run examples/block_kit_number_input.cr
crystal run examples/block_kit_file_input.cr
crystal run examples/block_kit_url_input.cr
crystal run examples/block_kit_email_input.cr
crystal run examples/block_kit_table.cr
crystal run examples/block_kit_context_actions.cr
crystal run examples/block_kit_data_table.cr
crystal run examples/block_kit_data_visualization.cr
crystal run examples/block_kit_card_carousel.cr
crystal run examples/block_kit_container.cr
crystal run examples/block_kit_rich_text_input.cr
crystal run examples/block_kit_markdown.cr
crystal run examples/block_kit_workflow_button.cr
crystal run examples/block_kit_alert.cr
crystal run examples/web_api.cr
crystal run examples/file_upload.cr
crystal run examples/thread_history.cr
crystal run examples/user_group.cr
crystal run examples/incident_triage.cr
crystal run examples/incident_channel.cr
crystal run examples/streaming.cr
crystal run examples/assistant_thread.cr
crystal run examples/plan.cr
crystal run examples/attachments.cr
crystal run examples/ephemeral_reply.cr
crystal run examples/event_delivery.cr
crystal run examples/event_catalog.cr
crystal run examples/assistant_events.cr
crystal run examples/socket_mode_protocol.cr
crystal run examples/socket_mode_client.cr
crystal run examples/interaction_context.cr
crystal run examples/slash_command.cr
crystal run examples/received_blocks.cr
crystal run examples/workflow_step.cr
crystal run examples/testing.cr
crystal run examples/app.cr
crystal run examples/app_manifest.cr
```

The examples show Web API calls and error codes, channel history and thread replies across cursor pages, workspace members read into an on-call user group, an incident channel created, staffed, and archived, an incident message acknowledged with a reaction, a pin, and a runbook bookmark, a file upload, a remote file share, message construction, a message with a colored attachment and metadata, an ephemeral thread reply with a permalink and a scheduled reminder, a signed button and form submission, Home publishing and state, static selections, overflow menus, checkbox selections, radio selections, user assignments and reviewers, external option suggestions, message status updates, modal updates and pushes, modal alerts, uploaded files, message workflow buttons, typed blocks of a received message, routed app events and message subtypes, routed assistant thread and agent session events, Socket Mode frames with their acknowledgments, a Socket Mode connection to a local server, a slash command response with a `response_url` reply, a custom workflow step that completes or fails its execution, an app that answers a signed mention and a button click through its HTTP receiver, an offline test of a slash command handler, and an app manifest that is validated, fixed, created, and exported. A separate demo app is at [hirobot.app](https://github.com/the-business-factory/hirobot.app).

## Contributing

Run `shards install`, `crystal spec`, `crystal tool format --check`, and `crystal run lib/ameba/src/cli.cr --no-color` before a pull request. Tests run offline with synthetic credentials. See [test instructions](spec/support/README.md) for the few checks that start child processes.

Contributors: [Rob Cole](https://github.com/robcole) and [Alex Piechowski](https://github.com/grepsedawk).
