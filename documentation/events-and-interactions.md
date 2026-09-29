# Events and interactions

Receive Slack requests over HTTP without the app framework: verify the signed request, parse the body for its route, and write the acknowledgment. `Slack::App` does these steps for you; see [App listeners](app.md). Socket Mode delivers the same payloads over a WebSocket; see [Socket Mode](socket-mode.md).

## Minimal example

```crystal
require "slack"

verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(signing_secret))

# POST /slack/commands
command = Slack::Commands.parse(verifier.verify(request).body)
context.response.content_type = "application/json"
context.response.print(Slack::Commands::Response.new(text: "Deploying #{command.text}.").to_json)
# {"response_type":"ephemeral","text":"Deploying api."}
```

| Route | Parser | Result |
| --- | --- | --- |
| Events API Request URL | `Slack::Events.parse` | `Slack::VerifiedEvent`, `Slack::UrlVerification`, or `Slack::AppRateLimited` |
| Interactivity Request URL and Options Load URL | `Slack::Interactions.parse` | A `Slack::Interaction`: `BlockAction`, `BlockSuggestion`, `MessageAction`, `Shortcut`, `ViewSubmission`, or `ViewClosed` |
| Slash command URL | `Slack::Commands.parse` | `Slack::Command` |

Give each parser only a body that `Verifier#verify` returned.

## Verify the request

Create one `Slack::Webhooks::Verifier` with the app's signing secret. The library has no global settings and reads no environment variables, so the application supplies the secret. Give the original `HTTP::Request` to `Verifier#verify`. It reads the body once, and checks the timestamp and the `v0` signature against the exact bytes. It returns a `VerifiedRequest` with `body` and `timestamp`:

```crystal
verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(signing_secret))

# Events API route: Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited
envelope = Slack::Events.parse(verifier.verify(request).body)
# Slash command route
command = Slack::Commands.parse(verifier.verify(request).body)
# Interactivity route: exactly one `payload` form field
interaction = Slack::Interactions.parse(verifier.verify(request).body)
```

| Error | Cause |
| --- | --- |
| `Slack::Errors::InvalidWebhookRequest` | A missing or malformed header or body |
| `Slack::Errors::ReplayAttack` | A timestamp outside `delivery_time_limit` |
| `Slack::Errors::SignatureMismatch` | An incorrect signature |
| `Slack::Auth::ContractError` with `InvalidConfiguration` | A blank secret or a negative limit, when you create the verifier |

The default `delivery_time_limit` is five minutes in both directions. Pass `delivery_time_limit:` to change it, and `clock:` (a `Slack::Auth::Clock`) to test with a fixed time.

Timestamp checks reject stale requests; they do not suppress duplicate deliveries. Keep an application event ID registry if duplicate processing matters. To select an installation for the request, use `Slack::Auth::RequestAuthorizer`; see [authentication](authentication.md#signed-requests-and-installations).

## Events API

`Slack::Events.parse` returns one of three envelopes:

- `Slack::UrlVerification`: return `#response` as the HTTP response body, so Slack can confirm the Request URL.
- `Slack::AppRateLimited`: Slack sends it instead of events when the app would get more than 30,000 events in one hour from one workspace. It has no inner event. `minute_rate_limited` gives the minute when the limit started. Return HTTP 200.
- `Slack::VerifiedEvent`: the inner `event` is a typed struct for mapped types.

An event type that the library does not map decodes as `Slack::Events::Unknown`: `type` gives the event type and `raw` keeps the complete event JSON. Match `Unknown` explicitly. Do not log `raw`: it can hold credentials, such as a workflow `bot_access_token`.

```crystal
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

The envelope also gives `event_id`, `team_id`, `api_app_id`, `authorizations`, `is_ext_shared_channel`, `context_team_id`, `context_enterprise_id`, and `event_context`. Each optional value is nil when Slack omits it.

### Typed events

These inner event types decode as typed structs in `Slack::Events`:

| Group | Event types |
| --- | --- |
| App | `app_home_opened`, `app_mention`, `app_installed`, `app_deleted`, `app_requested`, `app_uninstalled`, `tokens_revoked`, `function_executed` |
| Channels and members | `channel_created`, `channel_deleted`, `channel_rename`, `channel_archive`, `channel_unarchive`, `member_joined_channel`, `member_left_channel`, `team_join` |
| Messages | `message`, `link_shared`, `message_metadata_posted`, `message_metadata_updated`, `message_metadata_deleted`, `pin_added`, `pin_removed`, `reaction_added`, `reaction_removed` |
| Users, groups, and emoji | `user_change`, `user_status_changed`, `subteam_created`, `subteam_updated`, `subteam_members_changed`, `subteam_self_added`, `subteam_self_removed`, `emoji_changed` |
| App threads and agents | `assistant_thread_started`, `assistant_thread_context_changed`, `app_context_changed`, `agent_session_stopped`, `agent_session_title_changed` |

User, user group, app request, and pinned item objects stay raw `JSON::Any`. Message metadata gives `event_type` and a raw `event_payload`. For `function_executed`, see [Workflow steps](workflows.md#read-the-event).

### Mentions and reactions

`Slack::Events::AppMentioned` gives the message that mentions the app: `channel`, `user`, `text`, `ts`, and `event_ts`. `thread_ts` is nil for a mention at the top level. `team` is nil when Slack omits it. `blocks` decodes the message blocks. To reply in the thread of the mention, use `thread_ts || ts`:

```crystal
app.event("app_mention") do |ctx|
  mention = ctx.event
  next unless mention.is_a?(Slack::Events::AppMentioned)
  ctx.say("On it.", thread_ts: mention.thread_ts || mention.ts)
end
```

The `item` of `reaction_added` and `reaction_removed` is a `Slack::EventData::ReactionItem`: `Message` (`channel`, `ts`, `channel_type`), `File` (`file`), `FileComment` (`file`, `file_comment`), or `Unknown` (`type`, `raw`) for another item type. Only a `Message` item has a channel, so `say` in a listener for a reaction on a file raises `Slack::App::NoReplyTarget`. `item_user` is nil for a message without a user author, such as an incoming webhook message.

### Message subtypes

A `message` event without a `subtype` decodes as `Slack::Events::Message`. A `message` event with a `subtype` selects a struct in the `Slack::Events::Message` namespace: `assistant_app_thread`, `bot_add`, `bot_message`, `channel_join`, `channel_leave`, `channel_name`, `channel_purpose`, `channel_topic`, `file_share`, `me_message`, `message_changed`, `message_deleted`, `message_replied`, `pinned_item`, `thread_broadcast`, and `unpinned_item`. A subtype that the library does not map decodes as `Slack::Events::Message::Unmapped`, with `subtype` and the complete event object in `raw`.

- `Message` always has `channel`, `channel_type`, `user`, `text`, `ts`, and `event_ts`. `team`, `bot_id`, `app_id`, `thread_ts`, `client_msg_id`, `parent_user_id`, and `attachments` are nil when Slack omits them.
- The subtype structs and `Message::Unmapped` inherit `Slack::Event`, not `Message`. Thus `is_a?(Slack::Events::Message)` matches only a message without a subtype. Match all typed subtypes with `Slack::Events::MessageSubtype`.
- A typed subtype gives `channel`, `channel_type`, and `event_ts` as nil when Slack omits them, as several reference examples do.
- `Message::Unmapped#to_json` emits `raw` unchanged. `raw` can hold private message content, so do not log it.
- A plain `message` event must have `channel`, `channel_type`, `user`, `text`, `ts`, and `event_ts`. The app rejects a delivery without one of these fields with HTTP 400, and no listener gets it. For example, Slack can send `message_replied` without its subtype. That delivery does not have `user` or `text`, so the app rejects it.
- A canvas mention arrives as `app_mention` with `subtype` `document_mention` and a `document_mention` value.
- `blocks` decodes the message blocks. See [Read blocks from messages and views](block-kit.md#read-blocks-from-messages-and-views).

```crystal
case event = envelope.event
when Slack::Events::LinkShared
  unfurl(event.channel, event.message_ts, event.links.map(&.url))
when Slack::Events::Message::ChannelTopic
  log("#{event.channel} topic: #{event.topic}")
when Slack::Events::Message
  log("#{event.user} in #{event.channel}: #{event.text}")
when Slack::Events::MessageSubtype
  log("Message subtype #{event.subtype}")
when Slack::Events::Message::Unmapped
  log("Unmapped message subtype #{event.subtype}")
end
```

### App thread and agent events

| Event type | Struct | Main values |
| --- | --- | --- |
| `assistant_thread_started` | `AssistantThreadStarted` | `assistant_thread` (`user_id`, `channel_id`, `thread_ts`, `context`) |
| `assistant_thread_context_changed` | `AssistantThreadContextChanged` | `assistant_thread` with the new `context` |
| `app_context_changed` | `AppContextChanged` | `context.entities` (`type`, `value`, `team_id`), most relevant first |
| `agent_session_stopped` | `AgentSessionStopped` | `channel`, `thread_ts`, `streaming_message_ts` |
| `agent_session_title_changed` | `AgentSessionTitleChanged` | `title`, `previous_title` |

`assistant_thread.context` is nil when Slack does not send it. Its `channel_id`, `team_id`, and `enterprise_id` are nil when Slack sends an empty context. Call `conversations.info` before you use `channel_id`, because the app can have no access to that channel.

The root message of an app thread has the subtype `assistant_app_thread`. It decodes as `Slack::Events::Message::AssistantAppThread`. Slack also sends this subtype inside other subtypes, such as the `message` of `message_changed`, so check `message.subtype` there:

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

The library does not call the app thread or agent session methods for these events, and Slack does not change a stopped session status by itself. To answer app threads, see [AI apps](ai-apps.md#answer-app-threads-with-the-assistant-helper).

### Retries

Slack retries a delivery up to three times when the app does not return HTTP 2xx within three seconds. `Slack::Events::Delivery.from_headers` reads `retry_num` and `retry_reason`; `retry?` is true for a retry. To stop retries for a failed delivery, add `Slack::Events::Delivery::NO_RETRY_HEADER` with `NO_RETRY_VALUE` (`X-Slack-No-Retry: 1`) to the non-2xx response. The library does not send responses or remove duplicate deliveries; use `event_id` for that.

## Interactions

`Slack::Interactions.parse` reads the one `payload` form field of the verified body. A body without exactly one `payload` field raises `Slack::Auth::RequestAuthorizationError`. For JSON already verified by trusted code, use `Slack::Interaction.from_json`.

| `type` | Struct | Sent for |
| --- | --- | --- |
| `block_actions` | `BlockAction` | A click or a dispatched input in a message, modal, or Home |
| `block_suggestion` | `BlockSuggestion` | An external select that loads options |
| `message_action` | `MessageAction` | A message shortcut |
| `shortcut` | `Shortcut` | A global shortcut |
| `view_submission` | `ViewSubmission` | A submitted modal |
| `view_closed` | `ViewClosed` | A closed modal, when `notify_on_close` is true |

An interaction type that the library does not map decodes as `Slack::Interactions::Unknown`: `type` gives the interaction type, `raw` keeps the complete payload, and `api_app_id`, `team`, `enterprise`, and `user` are read from it. `Slack::App` finds no listener for it and answers HTTP 200 with an empty body. Authorization runs first: when the authorizer rejects the payload, for example because `user` is missing, the answer is HTTP 401. Do not log `raw`: it can hold a `response_url`.

`Slack::Event::KNOWN_TYPES`, `Slack::Events::MessageFactory::KNOWN_SUBTYPES`, and `Slack::Interaction::KNOWN_TYPES` map each supported `type` or `subtype` string to a struct that it decodes as. In `Slack::Event::KNOWN_TYPES`, `message` maps to `Slack::Events::Message`, the struct for a message without a `subtype`. A message with a `subtype` decodes as the struct in `KNOWN_SUBTYPES` instead.

```crystal
Slack::Event::KNOWN_TYPES["app_mention"]                       # => Slack::Events::AppMentioned
Slack::Event::KNOWN_TYPES["message"]                           # => Slack::Events::Message
Slack::Events::MessageFactory::KNOWN_SUBTYPES["channel_topic"] # => Slack::Events::Message::ChannelTopic
```

### Read actions and state

`BlockAction#actions` gives typed ButtonAction, StaticSelectAction, MultiStaticSelectAction, ExternalSelectAction, MultiExternalSelectAction, OverflowAction, CheckboxesAction, RadioButtonsAction, UsersSelectAction, MultiUsersSelectAction, ChannelsSelectAction, MultiChannelsSelectAction, ConversationsSelectAction, MultiConversationsSelectAction, DatePickerAction, TimePickerAction, DatetimePickerAction, NumberInputAction, UrlInputAction, EmailInputAction, and RichTextInputAction values with block/action IDs and selections. It decodes the actions on the first call and keeps the result. `BlockAction#state` gives the `StateMap`. A dispatched `plain_text_input` action stays `UnknownAction`; read its text through `state`. Only `UnknownAction` and `UnknownStateValue` keep `raw` JSON. For another field, read the payload: `to_json` on the interaction writes it back unchanged.

Migrate from earlier versions: `BlockAction#decoded_actions` is now `#actions`, and `state_map` is now `state` on `BlockAction`, `View`, and `ViewSubmission`. Typed actions, state values, received blocks, and rich text nodes no longer have `raw`. `View#payload` and `ReceivedMessage#payload` are private. To read a field that the library does not model, parse the `to_json` of the interaction, view, or message:

```crystal
extra = JSON.parse(interaction.to_json)["actions"][0]["future_field"]?
```

Clicks on `feedback_buttons`, `icon_button`, and `workflow_button` elements decode as `FeedbackButtonsAction`, `IconButtonAction`, and `WorkflowButtonAction`. Slack does not document these action shapes. The feedback and icon fields come from the Bolt JS `FeedbackButtonsAction` and `IconButtonAction` types (SDK-sourced, unverified against live Slack). No SDK defines a workflow button action, so `WorkflowButtonAction` assumes that the click echoes the element: `text` and the raw `workflow` object. `action_id` and `block_id` are required. All other fields are nilable, so a different live shape still decodes. A known field with the wrong JSON type, such as a number `value`, raises `TypeMismatch`.

```crystal
case action = interaction.actions.first
when Slack::Interactions::FeedbackButtonsAction
  record_feedback(action.action_id, action.value) # value of the pressed button: "good" or "bad"
when Slack::Interactions::IconButtonAction
  delete_answer if action.action_id == "answer.delete"
when Slack::Interactions::WorkflowButtonAction
  trigger_url = action.workflow.try(&.["trigger"]?).try(&.["url"]?).try(&.as_s?)
end
```

```crystal
case interaction = Slack::Interactions.parse(verifier.verify(request).body)
when Slack::Interactions::ViewSubmission
  reason : String? = interaction.plain_text?("reason", "text")
  if color = interaction.state.static_select_value?("preferences", "color")
    selected = color.selected_option.try(&.value)
  end
end
```

`StateMap#plain_text?`, `#static_select_value?`, `#multi_static_select_value?`, `#external_select_value?`, `#multi_external_select_value?`, `#checkboxes_value?`, `#radio_buttons_value?`, `#users_select_value?`, `#multi_users_select_value?`, `#channels_select_value?`, `#multi_channels_select_value?`, `#conversations_select_value?`, `#multi_conversations_select_value?`, `#date_picker_value?`, `#time_picker_value?`, `#datetime_picker_value?`, `#number_input_value?`, `#file_input_value?`, `#url_input_value?`, `#email_input_value?`, and `#rich_text_input_value?` work on BlockAction, View, and ViewSubmission state.

- A missing block/action key returns nil.
- For an existing selection entry, the matching `selected_option_presence`, `selected_options_presence`, `selected_user_presence`, `selected_users_presence`, `selected_channel_presence`, `selected_channels_presence`, `selected_conversation_presence`, or `selected_conversations_presence` distinguishes Absent, Null, and Present.
- A cleared single choice can be null; a cleared multi choice can be a present empty array. `selected_options`, `selected_users`, `selected_channels`, and `selected_conversations` can also be nil if absent or null.
- Asking for the wrong typed family raises `TypeMismatch`, as do malformed known values; it does not silently return nil.
- Fields that the library does not model stay in the payload. `to_json` on the interaction writes the complete payload.

Received values are user input. The library does not apply outbound rules to them:

| Value | Check in the application | Guide |
| --- | --- | --- |
| Date, time, and timezone strings; datetime Unix seconds (`Int64?`) | Parse and check the range | [Choose a date and time](block-kit.md#choose-a-date-and-time), [Choose an instant](block-kit.md#choose-an-instant) |
| Number input value (a string) | Parse and check the range | [Enter a number](block-kit.md#enter-a-number) |
| URL and email input values | Check the scheme and host, or the address | [Enter a URL](block-kit.md#enter-a-url), [Enter an email address](block-kit.md#enter-an-email-address) |
| File IDs and `url_private` | A download needs a token with `files:read` | [Collect uploaded files](block-kit.md#collect-uploaded-files) |
| Selected users, channels, and conversations | A selected ID does not prove access or permission to post | [Select conversations](block-kit.md#select-conversations) |
| External select options | A suggestion does not prove that the user can access the option | [Load options from your app](block-kit.md#load-options-from-your-app) |
| Rich text mentions | A mention does not prove membership or permission | [Show rich text](block-kit.md#show-rich-text) |

### Read interaction context

Interactions tell the app where the user acted. Use these typed values to reply in the correct place:

- `BlockAction#container` decodes the source surface. `Container::Message` has `message_ts`, `channel_id`, and `is_ephemeral`. `Container::View` has `view_id`. `Container::MessageAttachment` has `message_ts`, `attachment_id`, `channel_id`, `is_ephemeral`, and `is_app_unfurl`. Other types decode as `Container::Unknown` with `type` and `raw`.
- `BlockAction#channel`, `MessageAction#channel`, and `Shortcut#channel` give `Channel` (`id`, `name`) when Slack sends a channel.
- `BlockAction#view_hash` and `View#view_hash` read the `hash` field. Send it as `hash` to `views.update` or `views.publish` to prevent a race with another update.
- `ViewSubmission#response_urls` gives `ResponseUrl` values (`response_url`, `block_id`, `action_id`, `channel_id`) for conversation selects with `response_url_enabled`. Absent and null give an empty array.
- `ViewClosed#is_cleared` is true when the user closed the whole view stack.
- `View` has typed getters for `id`, `team_id`, `type`, `title`, `callback_id`, `private_metadata`, `external_id`, `root_view_id`, `previous_view_id`, `app_id`, `bot_id`, `clear_on_close`, and `notify_on_close`. `View#[]` and `View#payload` keep all other fields.
- `BlockAction#message` and `MessageAction#message` give a `ReceivedMessage` with `ts`, `thread_ts`, `text`, `user`, and `blocks`. `to_json` writes the complete message. `View#blocks` decodes the view blocks. See [Read blocks from messages and views](block-kit.md#read-blocks-from-messages-and-views). `interactivity` stays raw JSON.
- `BlockAction#response_url` gives the reply webhook for a message click. Use it to reply to an ephemeral message, which `chat.update` cannot change. Slack deprecates `response_url` and `response_urls` only for apps created with the Deno Slack SDK.

```crystal
case interaction = Slack::Interactions.parse(verifier.verify(request).body)
when Slack::Interactions::BlockAction
  case container = interaction.container
  when Slack::Interactions::Container::Message
    # chat.update cannot change an ephemeral message.
    update_message(container.channel_id, container.message_ts) unless container.is_ephemeral
  when Slack::Interactions::Container::View
    refresh_view(container.view_id, interaction.view_hash)
  end
end
```

Typed getters read the payload when called. A malformed known field raises `TypeMismatch` with its path, such as `container.message_ts` or `view.title`. A non-object `container` also raises `TypeMismatch`.

Slack sends `function_data`, `interactivity`, and `bot_access_token` only for blocks and views that a custom workflow step created. `FunctionData` has `execution_id`, `function.callback_id`, and raw `inputs`. `bot_access_token` is an `Auth::Secret`: `inspect` and `to_s` redact it, and `to_json` omits it. `interactivity` can contain `interactor.secret`, so `inspect` and `to_s` redact it too; `interactivity` and `to_json` keep the complete object. An empty token makes the payload invalid. These fields do not change how `Auth::RequestAuthorizer` selects the installation. See [Handle a step](workflows.md#handle-a-step).

## Slash commands

`Slack::Commands.parse` decodes the verified form body and returns `Slack::Command` with `command`, `text`, `user_id`, `channel_id`, `team_id`, `response_url`, `trigger_id`, and the other documented fields. A repeated routing field raises `Slack::Auth::RequestAuthorizationError`.

Return `Slack::Commands::Response` as the HTTP 200 `application/json` body within three seconds. It holds `text` or a `UI::Message`. The response is ephemeral by default: only the user who ran the command sees it. With `:in_channel`, everyone in the conversation sees the response and the command. To acknowledge without a message, return an empty HTTP 200.

```crystal
command = Slack::Commands.parse(verifier.verify(request).body)
message = Slack::UI.message(fallback_text: "Deploying api.") do |builder|
  builder.section(Slack::UI.mrkdwn("*Deploying api*"))
end
body = Slack::Commands::Response.new(message: message, response_type: :in_channel).to_json
# {"response_type":"in_channel","text":"Deploying api.","blocks":[{"type":"section",...}]}
```

## Acknowledgments

Answer every request with HTTP 200 within three seconds. An empty body is a plain acknowledgment. These values give the JSON body of an acknowledgment with a response:

| Value | Request | Effect | Guide |
| --- | --- | --- | --- |
| `Slack::Commands::Response` | Slash command | Shows a message | [Slash commands](#slash-commands) |
| `Slack::Interactions::BlockSuggestionResponse` | `block_suggestion` | Gives the options of an external select | [Load options from your app](block-kit.md#load-options-from-your-app) |
| `Slack::Interactions::ModalErrors` | `view_submission` | Shows errors on Input blocks | [Return modal validation errors](block-kit.md#return-modal-validation-errors) |
| `Slack::Interactions::ModalUpdate` | `view_submission` | Replaces the submitted view | [Update a modal in its submission acknowledgment](block-kit.md#update-a-modal-in-its-submission-acknowledgment) |
| `Slack::Interactions::ModalPush` | `view_submission` | Pushes a new view | [Push a view in a submission acknowledgment](block-kit.md#push-a-view-in-a-submission-acknowledgment) |
| `Slack::Interactions::ModalClear` | `view_submission` | Closes all views | [Close the modal stack after submission](block-kit.md#close-the-modal-stack-after-submission) |

These values need no token and make no API call. Socket Mode sends the same values in `Slack::SocketMode::Acknowledgment`. The application owns response delivery and timing; `Slack::App` sends the acknowledgment for you.

## Reply through a response URL

Slash commands, message clicks (`BlockAction#response_url`), and some modal submissions (`ViewSubmission#response_urls`) give a `response_url`. Use `Slack::Interactions::ResponseUrlResponder` to post a `ResponseUrlMessage` to it. Still acknowledge the original request within three seconds.

- Slack accepts up to five posts to one URL within 30 minutes. The library does not count uses or track expiry.
- A message without `response_type` is ephemeral.
- To reply in a thread, use `response_type: :in_channel` with `thread_ts`. The message then sends `replace_original: false`, so the reply does not overwrite the source message. The constructor rejects `thread_ts` without `:in_channel` or with `replace_original: true`.
- `replace_original: true` replaces the message that holds the used component. `ResponseUrlMessage.delete_original` deletes it; Slack requires `delete_original` as the sole attribute.
- The URL lets anyone post without a token. `inspect` and errors do not show it.

```crystal
responder = Slack::Interactions::ResponseUrlResponder.new(command.response_url)
reply = Slack::Interactions::ResponseUrlMessage.new(text: "Deployed api.", replace_original: true)
responder.post(Slack::Auth::HTTPTransport.new, reply)
# POST response_url, Content-Type: application/json
# {"replace_original":true,"text":"Deployed api."}
```

`post` makes one attempt. A non-2xx status raises `ResponseUrlError` with `http_status`, for example after the URL expires. A transport failure raises `Auth::ContractError` with `TransportFailure` or `UnknownRemoteOutcome`; after `UnknownRemoteOutcome`, Slack can have shown the message.

## Limits of the offline tests

The specs and examples use synthetic signed requests and payloads. They do not prove that Slack sends these events or payloads to an app, Slack retry timing, that Slack accepts or shows an acknowledgment or a `response_url` post, or the three-second timing on a live network.

## Examples

| Example | Shows |
| --- | --- |
| [`event_delivery.cr`](../examples/event_delivery.cr) | A signed retry of an unmapped event type, with its retry headers |
| [`event_catalog.cr`](../examples/event_catalog.cr) | Routed app events and message subtypes |
| [`assistant_events.cr`](../examples/assistant_events.cr) | Routed app thread and agent session events |
| [`interaction_context.cr`](../examples/interaction_context.cr) | A clicked message updated through its container, a submission's response URL target, and a cleared view stack |
| [`slash_command.cr`](../examples/slash_command.cr) | A signed command answered in the channel, then replaced through a stubbed `response_url` |
| [`received_blocks.cr`](../examples/received_blocks.cr) | The typed blocks of a clicked message |
