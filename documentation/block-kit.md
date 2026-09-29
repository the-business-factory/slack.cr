# Block Kit

Use `require "slack"` and `Slack::UI` to construct validated, immutable outbound values. Construction and JSON inspection need no Slack credentials. Sending needs a token with the relevant Slack API scope, and signed interaction handling needs the app signing secret. See [Build and send a message](#build-and-send-a-message) for a complete example, and [Offline examples](#offline-examples) for runnable workflows.

## Supported surfaces and placement

| Surface | Direct blocks | Input children | Send with |
| --- | --- | --- | --- |
| `Message` | Section, Actions, Divider, Header, Context, Image, Video, File, RichText, Table, DataTable, DataVisualization, Card, Carousel, Container, Markdown, ContextActions, Input, Plan, TaskCard | PlainTextInput, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker, DatetimePicker | `Slack::Api::ChatPostMessage`, `Slack::Api::ChatUpdate`, `Slack::Api::ChatPostEphemeral`, `Slack::Api::ChatScheduleMessage`, `Slack::UI::Unfurl` in `Slack::Api::ChatUnfurl` |
| `DisplayModal` | Section, Actions, Divider, Header, Context, Image, Video, RichText, Alert, Card | None, even if a submit label is supplied | `Slack::Api::ViewsOpen`, `Slack::Api::ViewsUpdate`, `Slack::Api::ViewsPush` |
| `FormModal` | Section, Actions, Divider, Header, Context, Image, Video, RichText, Alert, Card, Input, ModalInput, ViewInput | PlainTextInput, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker, DatetimePicker; NumberInput, FileInput, UrlInput, and EmailInput through ModalInput; RichTextInput through ViewInput | `Slack::Api::ViewsOpen`, `Slack::Api::ViewsUpdate`, `Slack::Api::ViewsPush` |
| `Home` | Section, Actions, Divider, Header, Context, Image, Video, RichText, Table, DataTable, DataVisualization, Card, Carousel, Container, Input, ViewInput | PlainTextInput, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker; RichTextInput through ViewInput | `Slack::Api::ViewsPublish` |

`FormModal` always needs a plain-text `submit` label, including forms without Input. `DisplayModal` cannot contain Input. Message and Home need no submit label. A Message can contain Input: [Slack's Input reference](https://docs.slack.dev/reference/block-kit/blocks/input-block.md) lists Messages, Modals, and Home. Some Input children are modal-only in Slack. `Blocks::ModalInput` holds these children; only `FormModal` accepts it. Other children are for modals and Home only. `Blocks::ViewInput` holds these children; only `FormModal` and `Home` accept it.

| Parent | Supported children |
| --- | --- |
| Section accessory | Button, Image element, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Overflow, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker, WorkflowButton (Message only) |
| Actions elements | Button, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Overflow, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker, DatetimePicker (not Home), WorkflowButton (Message only) |
| Context elements | PlainText, Mrkdwn, Image element |
| RichText elements | RichText Section, List, Preformatted, Quote |
| Table cells | Table::RawText, Table::RawNumber, Blocks::RichText |
| ContextActions elements (Message only) | FeedbackButtons, IconButton |
| DataTable header cells | Table::RawText, Table::RawNumber |
| DataTable row cells | Table::RawText, Table::RawNumber, Blocks::RichText |
| DataVisualization chart | DataVisualization::PieChart, BarChart, AreaChart, LineChart |
| Card actions | Button (up to 3) |
| Carousel elements | Blocks::Card (1 to 10) |
| Plan tasks (Message only) | Blocks::TaskCard (1 to 50) |
| Container child blocks | Section, Actions, Context, Divider, File (not Home), Header, Image, Input, RichText, Table, Video |
| Input element | PlainTextInput, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker, DatetimePicker (not Home) |
| ModalInput element (FormModal only) | NumberInput, FileInput, UrlInput, EmailInput |
| ViewInput element (FormModal and Home only) | RichTextInput |

Header, Context, Image, Video, and RichText blocks are display content on all four surfaces. A File block is a message-only representation. Table, DataTable, DataVisualization, and Container blocks are for messages and Home only. Markdown, ContextActions, Plan, and TaskCard blocks are for messages only; see [Show a plan with task cards](ai-apps.md#show-a-plan-with-task-cards). An Alert block is for modals only. A Card block is display content on all four surfaces; a Carousel block is for messages and Home only. An Image block or element needs alt text and exactly one public `image_url` or `SlackFile` source. `SlackFile` takes an ID or URL. Remote image availability and file access are checked by Slack. Section supports text, fields, and the listed accessory; Actions checks duplicate supplied action IDs within that block.

Static choices use plain-text `Option` values, optional `OptionGroup` values, and exactly one `options:` or `option_groups:` source. `StaticSelect` has one `initial_option`; `MultiStaticSelect` has `initial_options` and optional `max_selected_items`. Choice values must be unique within a menu, and initial selections must match offered options. Each group can contain up to 100 options. These two types use a **static** source. User, channel, and conversation selects use Slack-provided lists. External selects load options from your app; see [Load options from your app](#load-options-from-your-app).

The requests cover only their documented request fields; they are not complete wrappers for every Slack method field or view lifecycle action.

The machine-readable [support manifest](../spec/support/block_kit/support.yml) records detailed wire fields, upstream references, and repository evidence. Evidence paths in it are relative to the repository root.

## Messages

Build messages and send them with the `chat.*` requests.

### Build and send a message

Give a message an explicit top-level fallback for screen readers. `message_with_slack_generated_fallback` omits top-level text and asks Slack to derive it; the library does not create a partial summary. The local message limit is 50 blocks. Supplied block IDs must be unique.

```crystal
require "slack"

alias UI = Slack::UI
message = UI.message(fallback_text: "Request 42 needs approval.") do |builder|
  builder.section(UI.mrkdwn("*Request 42* needs approval"))
  builder.actions(elements: [UI::BlockElements::Button.new(
    text: UI.plain("Approve"), action_id: "request.approve", value: "42",
    accessibility_label: "Approve request 42"
  )])
end

client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])
request = Slack::Api::ChatPostMessage.new(channel: ENV["SLACK_CHANNEL_ID"], message: message)
puts request.to_pretty_json
response = client.call(request)
```

The request copies the message when you create it. It holds no token. `Slack::Api::Client#call` validates it before dispatch and raises `Slack::Api::Error` for API failures.

### Send a message

`ChatPostMessage` has one constructor for each kind of content:

| Constructor | Sends | Use it for |
| --- | --- | --- |
| `new(channel:, message:)` | `text` (the fallback) and `blocks` | Block Kit layouts |
| `new(channel:, text:)` | `text` | Plain messages; Slack formats `mrkdwn` |
| `new(channel:, markdown_text:)` | `markdown_text` (1 to 12,000 characters) | Standard Markdown, for example LLM output |

Slack rejects `markdown_text` together with `text` or `blocks` (`markdown_text_conflict`), so no constructor accepts both. All three constructors take the same options:

- `attachments`: up to 100 `UI::Attachment` values (see below).
- `thread_ts` and `reply_broadcast`: reply in a thread. `reply_broadcast: true` needs `thread_ts`.
- `metadata`: a `UI::MessageMetadata` value.
- `icon`: `UI::Icon::Emoji.new(":robot_face:")` or `UI::Icon::Url.new("https://...")`. A message has one icon.
- `username`: a custom bot name. `username` and `icon` need the `chat:write.customize` scope.
- `mrkdwn`, `parse` (`ChatPostMessage::Parse::None` or `Full`), `link_names`, `unfurl_links`, `unfurl_media`, `unfurl_app_links`, and `as_user` (for classic apps only).

```crystal
request = Slack::Api::ChatPostMessage.new(
  channel: "C123",
  markdown_text: "**Deploy 812** finished\n\n- api: healthy",
  thread_ts: "1710000000.000100",
  icon: Slack::UI::Icon::Emoji.new(":rocket:")
)
posted = client.call(request).message
posted.ts       # => "1710000123.000200"
posted.blocks   # => Array(Slack::Interactions::ReceivedBlock)
```

The response `message` is a `Slack::Models::Message`. It has typed `ts`, `type`, `subtype`, `text`, `user`, `bot_id`, `thread_ts`, and received `blocks`. `attachments` and `metadata` stay raw JSON.

The request does not send `current_draft_last_updated_ts` (Slack clients use it to sync drafts).

#### Add attachments and metadata

An attachment shows secondary content with a colored border. Slack recommends `blocks` and `color`; Slack keeps the other display fields for older apps. An attachment without blocks needs `fallback` or `text`. `author_link` and `author_icon` need `author_name`, and `footer_icon` needs `footer`. `footer` is at most 300 characters, and `image_url` cannot go with `thumb_url`. `Color` is `good`, `warning`, `danger`, or `#RRGGBB`. Attachment blocks follow the message block rules. Block IDs must be unique across the message and all its attachments, and all Markdown blocks in the request share the 12,000-character limit.

```crystal
checks = UI::Attachment.new(
  color: UI::Attachment::Color.hex("#2EB886"),
  blocks: [UI::Blocks::Context.new(elements: [UI.mrkdwn("api: healthy · web: healthy")])]
)
text_only = UI::Attachment.new(
  color: UI::Attachment::Color.danger, fallback: "web: unhealthy",
  title: "web", text: "Health check failed",
  fields: [UI::Attachment::Field.new(title: "Region", value: "us-east-1", short: true)]
)
request = Slack::Api::ChatPostMessage.new(
  channel: "C123", message: message, attachments: [checks, text_only],
  metadata: UI::MessageMetadata.new(event_type: "deploy_finished",
    event_payload: {"deploy_id" => JSON::Any.new("812")})
)
# {"channel":"C123","text":...,"blocks":[...],
#  "attachments":[{"color":"#2EB886","blocks":[...]},{"color":"danger","fallback":"web: unhealthy",...}],
#  "metadata":{"event_type":"deploy_finished","event_payload":{"deploy_id":"812"}}}
```

The library rejects more than 100 attachments, which is the `chat.postMessage` limit. The attachments guide advises no more than 20. For a message with only attachments, use `new(channel:, text:, attachments:)`: the text is the notification fallback. The interactive attachment fields `callback_id` and `actions` are not supported.

Metadata needs a nonblank `event_type` and a JSON object `event_payload`. Slack checks the size and format (`metadata_too_large`, `invalid_metadata_format`). Offline tests do not prove that Slack accepts or shows a message.

### Build a remote file block

A File block shows a remote file. Slack does not let apps add this block to messages directly. To share a remote file, the app adds it with `files.remote.add` and shares it with `files.remote.share`. To show it in a link preview, the app puts the block in a `UI::Unfurl` for `ChatUnfurl` (see [Unfurl links](#unfurl-links)). The [files guide](web-api.md#remote-files) shows the remote file requests. Slack shows File blocks in messages that contain remote files.

```crystal
file = UI::Blocks::File.new(external_id: "plan-2026-q4", block_id: "plan.file")
file.to_json
# {"type":"file","external_id":"plan-2026-q4","source":"remote","block_id":"plan.file"}
```

The block always sends `source: "remote"`. The `external_id` must not be empty, and `block_id` is limited to 255 characters. A `Message` can contain the block because Slack lists messages as its only surface; `DisplayModal`, `FormModal`, and `Home` reject `Blocks::File` at compile time. This placement does not make `chat.postMessage` or `chat.update` a supported way to share a file. Slack checks that the remote file exists. Received File blocks decode as `ReceivedBlocks::File`; see [Read blocks from messages and views](#read-blocks-from-messages-and-views). See the [file block reference](https://docs.slack.dev/reference/block-kit/blocks/file-block/), the [remote file guide](https://docs.slack.dev/messaging/working-with-files/), and the offline [remote-file example](../examples/block_kit_remote_file.cr).

### Update a message

Use `ChatUpdate` to replace the content of an existing message. Pass the channel ID and exact timestamp string returned when posting. For a direct message, use its conversation ID, not a user ID.

```crystal
updated_message = UI.message(fallback_text: "Request 42 approved.") do |builder|
  builder.section(UI.mrkdwn("*Request 42 approved.*"), block_id: "request.approved")
end
channel = response.channel || raise "Missing posted channel"
updated = client.call(Slack::Api::ChatUpdate.new(
  channel: channel, ts: response.ts, message: updated_message, as_user: true
))
puts updated.text
```

Like `ChatPostMessage`, `ChatUpdate` has three constructors: `message:`, `text:`, or `markdown_text:`. A `message:` update sends the text and nonempty blocks of an owned Message snapshot. It requires explicit fallback text: an update without text keeps the old fallback, so a Message with Slack-generated fallback is rejected. This is a library policy. Text is 1 to 4000 characters. A `text:` update removes the old blocks. Use fresh block IDs for each message version.

All constructors take these options:

- `attachments`: the `chat.postMessage` attachment rules apply. Slack keeps the old attachments when you omit them; pass an empty list to remove them.
- `metadata`: a `UI::MessageMetadata` that replaces the old metadata. Slack keeps the old metadata when you omit it. This library cannot remove metadata.
- `file_ids`: IDs of files to share with the message.
- `reply_broadcast`: shows an existing thread reply in the channel.
- `parse` (`None` or `Full`; Slack's update default is `client`), `link_names`, and `as_user` (for classic apps only).

```crystal
client.call(Slack::Api::ChatUpdate.new(channel: "C123", ts: "1710000000.000200",
  text: "Build 7 passed", attachments: [] of Slack::UI::Attachment))
# {"channel":"C123","ts":"1710000000.000200","text":"Build 7 passed","attachments":[]}
```

`channel` must not be blank. `ts` must contain digits, a decimal point, and fractional digits; it remains a string without fixed digit counts or rounding. `Client#call` and JSON serialization reject invalid local values before dispatch. `call` returns `Slack::Models::Chat::UpdateMessage`, with `channel`, `ts`, `text`, and optional raw `message` JSON. API failures raise `Slack::Api::Error`.

The token needs `chat:write`, and only messages owned by the authenticated user or bot can be updated. Ephemeral messages are unsupported. Slack checks ownership, permissions, message state, and rendering. Slack error codes such as `message_not_found`, `edit_window_closed` (the workspace edit window is closed), and `streaming_state_conflict` arrive as `Slack::Api::Error#code`. See the [chat.update reference](https://docs.slack.dev/reference/methods/chat.update/) and the offline [message-update example](../examples/block_kit_message_update.cr); stubs do not prove live acceptance.

### Reply to one user

`ChatPostEphemeral` shows a message that only `user` can see. It has the same three content constructors and content rules as `ChatPostMessage`, and takes `attachments`, `thread_ts`, `parse`, `link_names`, `username`, `icon`, and `as_user` (for classic apps only).

```crystal
reply = client.call(Slack::Api::ChatPostEphemeral.new(
  channel: "C123", user: "U123", text: "Only you can see this.", thread_ts: "1710000000.000100"))
reply.message_ts # => "1710000050.000200"
```

The user must be active and a member of the channel; Slack does not guarantee delivery. You cannot update the message with `message_ts`. Slack disregards event metadata on ephemeral messages, so the request has no `metadata`.

### Schedule a message

`ChatScheduleMessage` posts a message later. It has the three content constructors and takes `attachments`, `thread_ts`, `reply_broadcast`, `parse`, `link_names`, `unfurl_links`, `unfurl_media`, and `as_user`. `post_at` is a `Time`; the request sends Unix seconds.

```crystal
scheduled = client.call(Slack::Api::ChatScheduleMessage.new(
  channel: "C123", post_at: Time.utc + 1.day, text: "Standup in 5 minutes"))
scheduled.scheduled_message_id # => "Q1298393284"

client.each_page(Slack::Api::ChatScheduledMessagesList.new(channel: "C123")) do |page|
  page.model.scheduled_messages.each { |item| puts "#{item.id} at #{item.post_at}" }
end
client.call(Slack::Api::ChatDeleteScheduledMessage.new(channel: "C123", scheduled_message_id: scheduled.scheduled_message_id))
```

Slack accepts times up to 120 days ahead and 30 scheduled messages per channel in 5 minutes. The library does not read the clock: Slack returns `time_in_past` or `time_too_far`. Slack documents that a scheduled message with metadata does not post, so the request has no `metadata`. `ChatScheduledMessagesList` takes optional `channel`, `oldest` and `latest` times, `team_id`, `cursor`, and `limit`.

### Unfurl links

`ChatUnfurl` adds previews to links in a message. Identify the message with `channel:` and `ts:`, or pass the `unfurl_id:` and `source:` of a `link_shared` event. `unfurls` maps each URL to a `UI::Unfurl` (message blocks and an optional composer preview) or a `UI::Attachment`.

```crystal
unfurl = UI::Unfurl.new(
  blocks: [UI::Blocks::Section.new(text: UI.mrkdwn("*Issue 7*: Login fails"))],
  preview: UI::Unfurl::Preview.new(title: "Issue 7", icon_url: "https://example.com/icon.png"))
client.call(Slack::Api::ChatUnfurl.new(unfurl_id: "gryl3kb80b3wm49ihzoo35fyqoq08n2y",
  source: Slack::Api::ChatUnfurl::Source::Composer, unfurls: {"https://example.com/issues/7" => unfurl}))
# {"unfurl_id":"gryl3kb...","source":"composer","unfurls":{"https://example.com/issues/7":
#   {"blocks":[...],"preview":{"title":{"type":"plain_text","text":"Issue 7"},"icon_url":"https://example.com/icon.png"}}}}
```

Unfurl blocks follow the message block rules. Slack shows the preview only in the message composer. To ask the user to connect an account first, pass `user_auth_required`, `user_auth_message`, `user_auth_url`, or `user_auth_blocks`. Slack checks the link and the message.

### Other chat requests

| Request | Sends | Returns |
| --- | --- | --- |
| `ChatDelete.new(channel:, ts:, as_user: nil)` | `chat.delete` | `channel`, `ts` |
| `ChatGetPermalink.new(channel:, message_ts:)` | `chat.getPermalink` | `channel`, `permalink` |
| `ChatMeMessage.new(channel:, text:)` | `chat.meMessage` | `channel`, `ts` |

See the offline [ephemeral reply example](../examples/ephemeral_reply.cr). Offline tests do not prove that Slack accepts or shows a message.

## Interactive elements

Add elements that users click or select. Slack sends each action to the app; see [Read actions and state](events-and-interactions.md#read-actions-and-state).

### Add an overflow menu

Use `BlockElements::Overflow` in a Section accessory or Actions block on any surface. It accepts one to five `CompositionObjects::OverflowOption` values, optional `action_id`, and optional `confirm`. Overflow cannot be an Input element.

```crystal
menu = UI::BlockElements::Overflow.new(action_id: "request.more", options: {
  UI::CompositionObjects::OverflowOption.new(text: UI.plain("Archive"), value: "archive"),
  UI::CompositionObjects::OverflowOption.new(text: UI.plain("Details"), value: "details",
    description: UI.plain("Open request"), url: "https://example.com/requests/42"),
})
section = UI::Blocks::Section.new(text: UI.plain("Request 42"), accessory: menu)
```

Option labels and optional descriptions use plain text, up to 75 characters. Values are required, unique within the menu, and limited to 150 characters. URLs allow up to 3000 characters; action IDs allow 255. A nonempty option list is library policy. `OverflowOption` is separate from static-select `Option`, so URL options cannot be passed to static selects. See Slack's [Overflow](https://docs.slack.dev/reference/block-kit/block-elements/overflow-menu-element/) and [Option](https://docs.slack.dev/reference/block-kit/composition-objects/option-object/) references.

On receipt, `OverflowAction#selected_option` exposes the selected value and text through the received `SelectedOption` type. It requires a selection. `SelectedOption#url` is the URL of a URL choice, or nil. Other received option fields stay in `raw`; outbound size rules do not apply to received data. Overflow has no typed state-map entry. URL choices also send an interaction: acknowledge it within three seconds, even when the browser opens the URL.

### Add checkboxes

Use `BlockElements::Checkboxes` with one to ten `CompositionObjects::CheckboxOption` values. Section and Actions support checkboxes on all surfaces; Input supports Message, FormModal, and Home. Checkbox labels and descriptions accept plain text or Markdown, up to 75 characters. Values allow 150 characters and must be unique. URL options remain exclusive to Overflow.

```crystal
digest = UI::CompositionObjects::CheckboxOption.new(
  text: UI.mrkdwn("*Daily digest*"), value: "digest",
  description: UI.mrkdwn("_Once a day_"))
control = UI::BlockElements::Checkboxes.new(
  options: {digest}, initial_options: {digest}, action_id: "notifications",
  focus_on_load: false)
```

`initial_options` must exactly match offered options, including text formatting and descriptions. Repeated initial selections and empty option lists are rejected by library policy. Omit `initial_options` or supply an empty collection for no initial selection. Optional `confirm` uses the existing confirmation type. Optional `action_id` allows 255 characters. `focus_on_load` participates in the single-focus rule for views. See Slack's [Checkboxes](https://docs.slack.dev/reference/block-kit/block-elements/checkboxes-element/) and [Option](https://docs.slack.dev/reference/block-kit/composition-objects/option-object/) references.

Checkbox interactions decode as `CheckboxesAction`; state entries decode as `CheckboxesValue`. Read `selected_options` through the action or `state_map.checkboxes_value?(block_id, action_id)`. A cleared selection is a present empty array. Absent and null selections both return nil, with `selected_options_presence` distinguishing them. Received options use `SelectedOption`. `description` is a `ReceivedText?`. Unknown fields stay in `raw`, without outbound validation. Set `dispatch_action: true` on an Input block to receive actions when its checkboxes change; submissions also include their state.

### Add radio buttons

Use `BlockElements::RadioButtons` with one to ten `CompositionObjects::RadioOption` values. Section and Actions support radio buttons on all surfaces; Input supports Message, FormModal, and Home. Labels and descriptions accept plain text or Markdown, up to 75 characters. Values allow 150 characters and must be unique. Radio options do not accept URLs.

```crystal
digest = UI::CompositionObjects::RadioOption.new(
  text: UI.mrkdwn("*Digest*"), value: "digest",
  description: UI.mrkdwn("_Once a day_"))
immediate = UI::CompositionObjects::RadioOption.new(
  text: UI.plain("Immediate"), value: "immediate")
control = UI::BlockElements::RadioButtons.new(
  options: {digest, immediate}, initial_option: digest,
  action_id: "delivery", focus_on_load: false)
```

`initial_option` must exactly match one offered option, including text formatting and description. Omit it for no initial selection. Empty option lists are rejected by library policy. Optional `confirm` uses the existing confirmation type. Optional `action_id` allows 255 characters. `focus_on_load` participates in the single-focus rule for views. Collections are consumed once into owned snapshots. See Slack's [Radio buttons](https://docs.slack.dev/reference/block-kit/block-elements/radio-button-group-element/) and [Option](https://docs.slack.dev/reference/block-kit/composition-objects/option-object/) references.

Read `RadioButtonsAction#selected_option` or `state_map.radio_buttons_value?(block_id, action_id)`. A selection is a received `SelectedOption`. Both an absent field and explicit null return nil; `selected_option_presence` distinguishes Absent, Null, and Present. A present option can have an empty string value. `SelectedOption#description` is a `ReceivedText?`. Unknown fields remain in `raw`, and outbound limits do not apply to received data. Malformed known fields raise `TypeMismatch`. Set `dispatch_action: true` on an Input block to receive selection changes; submissions also include state.

Radio interactions decode as `RadioButtonsAction` and `RadioButtonsValue`.

### Select an owner and reviewers

Use `BlockElements::UsersSelect` for one user and `MultiUsersSelect` for several users. Both work in Section and Actions on all surfaces, and in Input on Message, FormModal, and Home. Slack supplies the users visible to the person using the menu.

```crystal
owner = UI::BlockElements::UsersSelect.new(
  action_id: "owner", initial_user: "U123",
  placeholder: UI.plain("Choose owner"), focus_on_load: false
)
reviewers = UI::BlockElements::MultiUsersSelect.new(
  action_id: "reviewers", initial_users: {"U123", "U456"},
  max_selected_items: 3, placeholder: UI.plain("Choose reviewers")
)
```

Both types support optional `action_id` (255 characters), plain-text `placeholder` (150 characters), `confirm`, and `focus_on_load`. Only one element per view can request focus. Single selection uses `initial_user`; multiple selection uses `initial_users` and optional `max_selected_items` (at least one). Omission, explicit false, and an empty initial array remain distinct. Initial user collections are copied once, and getters return snapshots.

The library rejects empty initial IDs, repeated initial users, and an initial count above the supplied maximum as local policy. It does not impose ID prefixes or lengths, check remote user existence, or require static options. Slack controls the available user list and remote acceptance. See the [single-user fields](https://docs.slack.dev/reference/block-kit/block-elements/select-menu-element/#users_select) and [multi-user fields](https://docs.slack.dev/reference/block-kit/block-elements/multi-select-menu-element/#users_multi_select).

Read `UsersSelectAction#selected_user` (`String?`) and `MultiUsersSelectAction#selected_users` (`Array(String)?`), or use `state_map.users_select_value?` and `state_map.multi_users_select_value?` with block/action IDs. The corresponding `selected_user_presence` and `selected_users_presence` distinguish Absent, Null, and Present. A cleared single selection is null; a cleared multi-selection is a present empty array. A missing state entry returns nil. Received IDs have no outbound validation; malformed known values raise path-aware `TypeMismatch`, including the index of a malformed array item. Complete raw JSON remains available, and selected-array getters return copies. Input blocks can set `dispatch_action: true` for selection changes; submissions also carry state.

User interactions decode as `UsersSelectAction`/`MultiUsersSelectAction` and `UsersSelectValue`/`MultiUsersSelectValue`. The [offline workflow](../examples/block_kit_users_select.cr) assigns an owner, opens a reviewer form, and verifies signed submission state.

### Select notification channels

Use `BlockElements::ChannelsSelect` for one public channel and `MultiChannelsSelect` for several. Slack supplies public channels visible to the person using the menu. Both controls work in Section and Actions on all surfaces, and in Input on Message, FormModal, and Home.

```crystal
notification = UI::BlockElements::ChannelsSelect.new(
  action_id: "notification", initial_channel: "C123",
  placeholder: UI.plain("Choose channel")
)
destinations = UI::BlockElements::MultiChannelsSelect.new(
  action_id: "destinations", initial_channels: {"C123", "C456"},
  max_selected_items: 3, placeholder: UI.plain("Choose destinations")
)
```

Both support optional `action_id` (255 characters), plain-text `placeholder` (150 characters), `confirm`, and `focus_on_load`. Only one element per view can request focus. Multi-select supports `max_selected_items` of at least one. A supplied `initial_channels` must contain at least one ID, as documented by Slack; omit it for no initial selection. Collections are copied once, and getters return copies.

Empty initial IDs, repeated initial channels, and an initial count above a supplied maximum are rejected as library policy. There are no ID-prefix, ID-length, static-membership, or remote-existence checks. Conversation filters and default-to-current-conversation fields are not part of these controls. See the [single-channel fields](https://docs.slack.dev/reference/block-kit/block-elements/select-menu-element/#channels_select) and [multi-channel fields](https://docs.slack.dev/reference/block-kit/block-elements/multi-select-menu-element/#channel_multi_select).

Only `ChannelsSelect` accepts `response_url_enabled`. Slack documents it for Input blocks in modals. The library rejects any supplied value, including `false`, outside that placement; this field-presence restriction is library policy. Omit the field elsewhere. In modal Input, omitted, `false`, and `true` remain distinct. With `true`, Slack can return `response_urls` on submission; read them from `ViewSubmission#response_urls` (see [Read interaction context](events-and-interactions.md#read-interaction-context)). This adds no response-URL transport or delivery guarantee.

Read `ChannelsSelectAction#selected_channel` (`String?`) and `MultiChannelsSelectAction#selected_channels` (`Array(String)?`), or use `state_map.channels_select_value?` and `state_map.multi_channels_select_value?`. Their `selected_channel_presence` and `selected_channels_presence` distinguish Absent, Null, and Present. A cleared single selection is null; a cleared multi-selection is a present empty array. Missing state entries return nil. Received IDs have no outbound limits; malformed known fields raise path-aware `TypeMismatch`. Raw unknown fields are retained, and selected-array getters return copies. Input can set `dispatch_action: true` for selection changes.

Channel interactions decode as `ChannelsSelectAction`/`MultiChannelsSelectAction` and `ChannelsSelectValue`/`MultiChannelsSelectValue`. The [offline workflow](../examples/block_kit_channels_select.cr) selects a notification channel, opens a destination form, and reads signed submission state.

### Select conversations

Use `BlockElements::ConversationsSelect` for one conversation and `MultiConversationsSelect` for several. Slack supplies public and private channels, direct messages, and group direct messages visible to the user. Both controls work in Section and Actions on all surfaces, and in Input on Message, FormModal, and Home.

```crystal
filter = UI::CompositionObjects::ConversationFilter.new(
  include: {"public", "private", "im"}, exclude_bot_users: true
)
destination = UI::BlockElements::ConversationsSelect.new(
  action_id: "destination", default_to_current_conversation: true,
  filter: filter, placeholder: UI.plain("Choose conversation")
)
copies = UI::BlockElements::MultiConversationsSelect.new(
  action_id: "copies", initial_conversations: {"C123", "D456"},
  max_selected_items: 3, filter: filter
)
```

Both accept optional `action_id` (255 characters), plain-text `placeholder` (150 characters), `confirm`, `focus_on_load`, `filter`, and `default_to_current_conversation`. Only one element per view can request focus. Single selection uses `initial_conversation`; multiple selection uses a nonempty `initial_conversations` and optional `max_selected_items` of at least one. Omit initial choices for no explicit selection.

Slack documents different default precedence: single `initial_conversation` takes precedence over `default_to_current_conversation`; the multi-select reference says that when the default field is also supplied, `initial_conversations` is ignored. The library preserves both fields unchanged, including explicit false, and leaves the choice to Slack. See the [single-select](https://docs.slack.dev/reference/block-kit/block-elements/select-menu-element/) and [multi-select](https://docs.slack.dev/reference/block-kit/block-elements/multi-select-menu-element/) references.

A `ConversationFilter` needs at least one supplied field; an explicit false flag counts. Optional `include:` accepts a nonempty collection of `"im"`, `"mpim"`, `"private"`, and `"public"`. Optional `exclude_external_shared_channels` and `exclude_bot_users` preserve omission and false. The external-shared flag excludes channels, not users from shared channels. Filters are exclusive to conversation controls. See the [filter reference](https://docs.slack.dev/reference/block-kit/composition-objects/conversation-filter-object/).

Initial IDs and filter includes are copied in one pass; getters return copies. Empty IDs, repeated initial IDs, and an initial count above a supplied maximum are rejected as library policy. The library does not impose ID prefixes or lengths, check remote membership, or check an initial ID against a filter.

Only the single control accepts `response_url_enabled`. It is allowed only in modal Input blocks; rejecting a supplied false outside that placement is library policy, matching ChannelsSelect. Omit it elsewhere. Submission `response_urls` are available as typed `ResponseUrl` values; this adds no response-URL transport.

Read `ConversationsSelectAction#selected_conversation` (`String?`) and `MultiConversationsSelectAction#selected_conversations` (`Array(String)?`), or use `state_map.conversations_select_value?` and `state_map.multi_conversations_select_value?` with block/action IDs. Presence accessors distinguish Absent, Null, and Present. A cleared single selection is null; a cleared multi-selection is an empty array. Missing entries return nil, malformed known values raise path-aware `TypeMismatch`, and unknown fields stay in raw JSON. Received IDs have no outbound limits; selected-array getters return copies. Input can use `dispatch_action: true` for changes; submissions also carry state.

These controls decode as `ConversationsSelectAction`/`MultiConversationsSelectAction` and `ConversationsSelectValue`/`MultiConversationsSelectValue`. The [offline workflow](../examples/block_kit_conversations_select.cr) posts a filtered conversation menu, reads a signed action, opens a destination form, and reads its signed submission. It does not prove live permissions, rendering, default precedence, remote acceptance, or acknowledgment timing.

### Choose a date and time

Use separate `BlockElements::DatePicker` and `TimePicker` controls in Section or Actions on all surfaces, or in Input on Message, FormModal, and Home. These are calendar and clock choices; they do not represent an instant or create a scheduled job.

```crystal
date = UI::BlockElements::DatePicker.new(
  action_id: "date", initial_date: "2028-02-29",
  placeholder: UI.plain("Choose date")
)
time = UI::BlockElements::TimePicker.new(
  action_id: "time", initial_time: "09:30", timezone: "America/Chicago",
  focus_on_load: true
)
```

Both support optional `action_id` (255 characters), plain-text `placeholder` (150 characters), `confirm`, and `focus_on_load`. Omitted fields and explicit false stay distinct. One element per view can request focus. `initial_date` uses exact `YYYY-MM-DD`; local calendar validation requires a real Gregorian date in years 0001–9999, including leap-year rules. This year range is library policy, not a remote scheduling window. `initial_time` uses exact `HH:mm`, from `00:00` through `23:59`. See Slack's [date picker](https://docs.slack.dev/reference/block-kit/block-elements/date-picker-element/) and [time picker](https://docs.slack.dev/reference/block-kit/block-elements/time-picker-element/) fields and placement metadata.

Only TimePicker accepts `timezone`, an IANA timezone hint such as `America/Chicago`. The library sends it unchanged and does not consult the host timezone database or validate remote timezone support. Slack can return it on certain interactions, including submissions. The application owns timezone resolution, daylight-saving ambiguity, and any scheduling rules. For one instant, use the separate [datetime picker](#choose-an-instant).

Read `DatePickerAction#selected_date` and `TimePickerAction#selected_time`, or `state_map.date_picker_value?` and `state_map.time_picker_value?` with block/action IDs. Selections remain `String?`. Their `selected_date_presence` and `selected_time_presence` distinguish Absent, Null (cleared), and Present. TimePickerAction/TimePickerValue also expose optional `timezone` and `timezone_presence`. Missing state entries return nil. Empty or malformed-format strings remain present without outbound calendar/clock validation; wrong JSON types raise path-aware `TypeMismatch`. Unknown fields remain in `raw`. Input can set `dispatch_action: true` to receive changes.

Picker interactions decode as `DatePickerAction`/`TimePickerAction` and `DatePickerValue`/`TimePickerValue`. The [offline scheduling-choice workflow](../examples/block_kit_date_time_pickers.cr) posts a date choice, opens a form, and reads the final date, time, and timezone from a signed submission.

### Choose an instant

Use `BlockElements::DatetimePicker` for one date and time together. Slack sends and returns this value as a Unix timestamp in seconds. Put the picker in Actions or Input on a Message, DisplayModal (Actions only), or FormModal. Slack does not document it for Section accessories or Home, so a Section accessory does not compile and Home validation raises `home.datetimepicker.unsupported_surface`.

```crystal
start = UI::BlockElements::DatetimePicker.new(
  action_id: "start", initial_date_time: Time.utc(2028, 2, 29, 16, 30),
  focus_on_load: true
)
```

The picker supports optional `action_id` (255 characters), `initial_date_time`, `confirm`, and `focus_on_load`. It has no placeholder or timezone field. `initial_date_time` is a `Time`; the library sends whole seconds and drops sub-second precision. Slack documents a ten-digit timestamp, so the value must be from 2001-09-09T01:46:40Z through 2286-11-20T17:46:39Z. Omitted fields and explicit false stay distinct, and one element per view can request focus. See Slack's [datetime picker](https://docs.slack.dev/reference/block-kit/block-elements/datetime-picker-element/) fields and placement metadata.

Read `DatetimePickerAction#selected_date_time`, or `state_map.datetime_picker_value?` with block/action IDs. The selection is `Int64?` Unix seconds as received; use `Time.unix(seconds)` to get a UTC `Time`. `selected_date_time_presence` distinguishes Absent, Null (cleared), and Present. Missing state entries return nil. A non-integer selection or a wrong ID type raises path-aware `TypeMismatch`. Unknown fields remain in `raw`. The library does not apply outbound range rules to received values or create a scheduled job.

Datetime picker interactions decode as `DatetimePickerAction` and `DatetimePickerValue`. The [offline meeting-start workflow](../examples/block_kit_datetime_picker.cr) posts a proposed start, reads a signed choice, opens a form with that start, and reads the saved start from a signed submission.

### Load options from your app

Use `BlockElements::ExternalSelect` for one choice and `MultiExternalSelect` for several. Slack gets the options from your app. Both controls work in Section and Actions on all surfaces, and in Input on Message, FormModal, and Home.

Before you use them, set the **Options Load URL** under **Interactivity & Shortcuts** in the app settings. Slack sends a signed `block_suggestion` request to that URL when the menu opens and when the user types. `min_query_length` sets the minimum number of typed characters before Slack sends a request. Slack uses 3 if you omit it.

```crystal
project = UI::BlockElements::ExternalSelect.new(
  action_id: "project", placeholder: UI.plain("Find a project"),
  min_query_length: 2
)
related = UI::BlockElements::MultiExternalSelect.new(
  action_id: "related", max_selected_items: 3,
  initial_options: {UI::CompositionObjects::Option.new(text: UI.plain("Apollo"), value: "apollo")}
)
```

Both accept optional `action_id` (255 characters), plain-text `placeholder` (150 characters), `min_query_length`, `confirm`, and `focus_on_load`. Only one element per view can request focus. Single selection uses `initial_option`; multiple selection uses `initial_options` and optional `max_selected_items` of at least one. The library cannot compare initial options with remote results, so it checks only the option values. A negative `min_query_length`, empty `initial_options`, repeated initial values, and more initial options than `max_selected_items` are rejected as library policy. Initial options are copied in one pass; getters return copies. See Slack's [single-select](https://docs.slack.dev/reference/block-kit/block-elements/select-menu-element/#external_select) and [multi-select](https://docs.slack.dev/reference/block-kit/block-elements/multi-select-menu-element/#external_multi_select) references.

Verify the signed options-load request with a `Slack::Webhooks::Verifier` ([signed requests](events-and-interactions.md#verify-the-request)), then pass the verified body to `Slack::Interactions.parse`. It returns a `Slack::Interactions::BlockSuggestion`. Read `action_id`, `block_id`, and `value` (the typed query; it can be an empty string). `user`, `team`, `enterprise`, `api_app_id`, `token`, and `view` are typed as in other interactions; `container`, `channel`, and `message` stay raw JSON. A payload without a string `action_id`, `block_id`, or `value` raises `JSON::SerializableError`.

Answer with a `BlockSuggestionResponse` as HTTP 200 `application/json` within three seconds:

```crystal
case suggestion = Slack::Interactions.parse(verifier.verify(request).body)
when Slack::Interactions::BlockSuggestion
  options = find_projects(suggestion.value).first(100).map do |item|
    UI::CompositionObjects::Option.new(text: UI.plain(item.name), value: item.id)
  end
  body = Slack::Interactions::BlockSuggestionResponse.new(options: options).to_json
  # Send body with status 200 and Content-Type: application/json.
end
```

Supply `options:` (0 to 100 options; an empty list shows no results) or `option_groups:` (up to 100 `OptionGroup` values, each with 1 to 100 options). Values must be unique across the response; this is library policy. The response owns a copy of the collection. The library does not route the Options Load URL, run an HTTP server, or enforce the deadline. See the [block_suggestion payload](https://docs.slack.dev/reference/interaction-payloads/block_suggestion-payload/).

Read `ExternalSelectAction#selected_option` (`SelectedOption?`) and `MultiExternalSelectAction#selected_options` (`Array(SelectedOption)?`), or use `state_map.external_select_value?` and `state_map.multi_external_select_value?` with block/action IDs. Presence accessors distinguish Absent, Null, and Present. A cleared multi-selection is an empty array. Missing entries return nil, malformed known values raise path-aware `TypeMismatch`, and unknown fields stay in raw JSON. Received options have no outbound limits.

`block_suggestion` payloads decode as `BlockSuggestion`. External select actions and state decode as `ExternalSelectAction`/`MultiExternalSelectAction` and `ExternalSelectValue`/`MultiExternalSelectValue`. The [offline workflow](../examples/block_kit_external_select.cr) posts an external menu, answers a signed suggestion, reads a signed selection, opens a related-project form, and reads its signed submission. It does not prove live acceptance, rendering, or response timing.

### Add feedback and icon buttons

Use `Blocks::ContextActions` to add feedback buttons and icon buttons to a message, for example below an answer from your app. A block holds one to five `BlockElements::FeedbackButtons` or `BlockElements::IconButton` elements. `FeedbackButtons` has a positive and a negative `CompositionObjects::FeedbackButton`; each button needs text and a value. `IconButton` needs an `IconButtonIcon` (Slack supports only `Trash`) and text. Use `visible_to_user_ids` to show the icon button only to some users. If you omit it, all users see the button.

```crystal
feedback = UI::BlockElements::FeedbackButtons.new(action_id: "answer.feedback",
  positive_button: UI::CompositionObjects::FeedbackButton.new(text: UI.plain("Good"), value: "good"),
  negative_button: UI::CompositionObjects::FeedbackButton.new(text: UI.plain("Bad"), value: "bad"))
delete = UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash,
  text: UI.plain("Delete"), action_id: "answer.delete", visible_to_user_ids: {"U123"})
message = UI.message(fallback_text: "Answer") do |builder|
  builder.section(UI.plain("Rotate the signing secret in the app settings."))
  builder.context_actions({feedback, delete}, block_id: "answer.actions")
end
# {"type":"context_actions","block_id":"answer.actions","elements":[
#   {"type":"feedback_buttons","action_id":"answer.feedback",
#    "positive_button":{"text":{"type":"plain_text","text":"Good"},"value":"good"},"negative_button":{...}},
#   {"type":"icon_button","icon":"trash","text":{"type":"plain_text","text":"Delete"},
#    "action_id":"answer.delete","visible_to_user_ids":["U123"]}]}
```

Slack permits up to five elements. Feedback button text and `accessibility_label` are up to 75 characters, and values are up to 2000 characters. Icon buttons also accept `value`, `confirm`, and `accessibility_label`. Action IDs must be unique in the block. The library also requires at least one element, icon button text of up to 75 characters, and a nonempty `visible_to_user_ids` list with nonempty IDs. These checks are library policy. `Home`, `DisplayModal`, and `FormModal` reject `Blocks::ContextActions` at compile time, because Slack shows it only in messages.

A click decodes as `FeedbackButtonsAction` or `IconButtonAction`. See [Read actions and state](events-and-interactions.md#read-actions-and-state).

See Slack's [context actions block](https://docs.slack.dev/reference/block-kit/blocks/context-actions-block/), [feedback buttons](https://docs.slack.dev/reference/block-kit/block-elements/feedback-buttons-element/), and [icon button](https://docs.slack.dev/reference/block-kit/block-elements/icon-button-element/) references and the offline [context actions example](../examples/block_kit_context_actions.cr).

### Run a workflow from a message

Use `BlockElements::WorkflowButton` to start a workflow through its link trigger. Put it in a Section accessory or an Actions block on a Message. Slack documents it for messages only, so Home, DisplayModal, and FormModal validation raise `home.workflow_button.unsupported_surface` or `modal.workflow_button.unsupported_surface`.

```crystal
trigger = UI::CompositionObjects::WorkflowTrigger.new(
  url: "https://slack.com/shortcuts/Ft0123ABC456/xyz",
  customizable_input_parameters: {
    UI::CompositionObjects::WorkflowInputParameter.new(name: "incident_id", value: "INC-7"),
  })
button = UI::BlockElements::WorkflowButton.new(
  text: UI.plain("Start postmortem"), action_id: "postmortem.start",
  workflow: UI::CompositionObjects::Workflow.new(trigger: trigger),
  style: UI::BlockElements::ButtonStyle::Primary)
section = UI::Blocks::Section.new(text: UI.mrkdwn("*INC-7* is resolved."), accessory: button)
# {"type":"workflow_button","text":{"type":"plain_text","text":"Start postmortem"},"action_id":"postmortem.start",
#  "workflow":{"trigger":{"url":"https://slack.com/shortcuts/Ft0123ABC456/xyz",
#   "customizable_input_parameters":[{"name":"incident_id","value":"INC-7"}]}},"style":"primary"}
```

`text` (plain text, 75 characters), `workflow`, and `action_id` (255 characters) are required. `style` and `accessibility_label` (75 characters) are optional. The button has no `confirm`, `url`, or `value`. The trigger needs a `url`; an empty URL is rejected by library policy. Omit `customizable_input_parameters` to send no list. Slack checks that the URL belongs to a valid link trigger and that each parameter name and value match a customizable workflow input. End users can see parameter values, so do not send secrets. See Slack's [workflow button](https://docs.slack.dev/reference/block-kit/block-elements/workflow-button-element/) and [trigger object](https://docs.slack.dev/reference/block-kit/composition-objects/trigger-object/) references.

Slack does not document a `block_actions` payload for a workflow button click. If Slack sends one, it decodes as `WorkflowButtonAction`. See [Read actions and state](events-and-interactions.md#read-actions-and-state). The [offline incident workflow](../examples/block_kit_workflow_button.cr) posts workflow buttons with trigger inputs and shows the Home rejection. It does not prove that the trigger is valid or that the workflow runs.

`Blocks::Section::Accessory` and `Blocks::Actions::Element` include `WorkflowButton`.

## Display blocks

Show content that users read.

### Embed a video

A Video block shows an embedded player in a message, modal, or Home tab. It needs `alt_text`, a plain-text `title`, `thumbnail_url`, and `video_url`. Slack prefers `title_url` and `description`.

```crystal
message = Slack::UI.message(fallback_text: "Release 4.2 walkthrough video") do |builder|
  builder.video(
    alt_text: "Release 4.2 walkthrough",
    title: Slack::UI.plain("Release 4.2 walkthrough"),
    title_url: "https://videos.example.test/watch/release-4-2",
    description: Slack::UI.plain("Five minutes on what changed."),
    thumbnail_url: "https://videos.example.test/thumbs/release-4-2.jpg",
    video_url: "https://videos.example.test/embed/release-4-2",
    provider_name: "Example Video")
end
```

Local checks: title and description text fewer than 200 characters, `author_name` fewer than 50 characters, and valid absolute HTTPS URLs for `video_url` and `title_url`. Slack does more checks when it gets the request. The app needs the `links.embed:write` scope, and the `video_url` domain must be in the app's unfurl domains. The page must work in an iframe, must not be on a Slack domain, and must be reachable. A local check does not prove that Slack will play the video.

### Show rich text

Use `Blocks::RichText` for formatted display text. Build it from the `Slack::UI::RichText` types. The block holds containers, and the containers hold inline elements. The types enforce the parent rules that Slack documents:

| Container | Children |
| --- | --- |
| `RichText::Section`, `RichText::Quote` | Text, Link, Emoji, User, Usergroup, Channel, Broadcast, Date, Color, Team, File, Canvas, WorkflowMention |
| `RichText::Preformatted` | Text, Link |
| `RichText::List` | `RichText::Section` only |

```crystal
alias RT = Slack::UI::RichText
message = UI.message(fallback_text: "Release 2.0 is live") do |builder|
  builder.rich_text(block_id: "notes", elements: [
    RT::Section.new(elements: [
      RT::Text.new("Release "), RT::Text.new("2.0", style: RT::TextStyle.new(bold: true)),
      RT::Text.new(" is live for "), RT::Usergroup.new("S123"),
    ] of RT::Element),
    RT::List.new(RT::ListStyle::Bullet, elements: {
      RT::Section.new(elements: {RT::Link.new("https://example.com/changelog", text: "Changelog")}),
    }),
    RT::Preformatted.new(elements: {RT::Text.new("shards update")}, language: "shell"),
  ])
end
```

`TextStyle` has `bold`, `italic`, `strike`, `code`, `highlight`, `client_highlight`, `underline`, and `unlink`. The other inline elements use `Style`, which has the same flags without `code`. Omitted flags and explicit false stay distinct. Slack does not list `unlink` for dates, colors, and files; the library does not check this. `Broadcast` takes `BroadcastRange::Here`, `Channel`, or `Everyone`. `Date` needs a Unix `timestamp` in seconds and a `format` such as `"{date_short} at {time}"`; `timezone`, `url`, and `fallback` are optional. `Channel` has an optional `tab_id`. A `List` has optional `indent`, `offset`, and `border`; `Preformatted` has `border` and `language`; `Quote` has `border`. To nest a list, use a second `List` with a larger `indent`.

Use these elements to link to Slack objects:

| Element | Required | Optional |
| --- | --- | --- |
| `Team` | `team_id` | `style` |
| `File` | `file_id` | `text` (the file title), `url`, `style` |
| `Canvas` | `file_id` | `label`, `hide_title`, `section_id`, `text` (the canvas title), `url`, `style` |
| `WorkflowMention` | `workflow_id`, `function_trigger_id`, `text` | `url`, `style` |

```crystal
RT::Section.new(elements: [
  RT::Text.new("Read the ", style: RT::TextStyle.new(highlight: true)),
  RT::Canvas.new("F123", section_id: "temp:C:rollout", text: "Rollout steps"),
  RT::Text.new(", then "),
  RT::WorkflowMention.new("Wf123", function_trigger_id: "Ft123", text: "request access"),
] of RT::Element)
```

The block and each container need at least one child. Required strings, such as text, URLs, IDs, and date formats, must not be empty. `border` is 0 or 1, and `indent` and `offset` are not negative. These checks are library policy. Other element types, such as `citation`, `tag`, and `message_mention`, are not supported for outbound values. See Slack's [rich text block](https://docs.slack.dev/reference/block-kit/blocks/rich-text-block/) reference and its linked element pages.

Received `rich_text` blocks decode as `Slack::Interactions::RichText::Block`, for example in `Slack::Events::Message#blocks` (see [Read blocks from messages and views](#read-blocks-from-messages-and-views)). To read one raw block, use `Slack::Interactions::RichText::Block.new(raw, path)`. The received types have the same names in `Slack::Interactions::RichText`. They keep `style`, `range`, and numbers as sent, allow empty children, and keep all JSON in `raw`. Slack sets some fields only to describe a received node. Read them on the received types: link `from_llm`, `is_slack_url`, and `truncated`; user and channel `from_llm`; file and canvas `is_skill_invocation`; and workflow mention `channel_id` and `ts`. An unknown node type becomes `RichText::Unknown`. A missing required field, a wrong JSON type, or a known node in the wrong position raises a `TypeMismatch` with the JSON path.

```crystal
event.blocks.each do |reply|
  next unless reply.is_a?(Slack::Interactions::RichText::Block)
  reply.elements.each do |container|
    next unless container.is_a?(Slack::Interactions::RichText::Section)
    container.elements.each do |element|
      puts element.user_id if element.is_a?(Slack::Interactions::RichText::User)
    end
  end
end
```

Received `team`, `file`, `canvas`, and `workflow_mention` nodes decode as `RichText::Team`, `File`, `Canvas`, and `WorkflowMention`. The style flags, `Channel#tab_id`, and `Date#timezone` are optional named arguments.

### Show a table

Use `Blocks::Table` to show rows of cells in a message or on Home. A cell is a `Table::RawText`, a `Table::RawNumber`, or a `Blocks::RichText` for mentions, links, and styles. `RawNumber` sends the number as `value` and shows `text`. Use a `Table::ColumnSetting` to set `align` and `is_wrapped` for a column. Use `nil` to keep the defaults for a column (Slack receives `null`).

```crystal
alias RT = Slack::UI::RichText
owner = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::User.new("U123")})})
message = UI.message(fallback_text: "Q3 revenue by region") do |builder|
  builder.table(block_id: "q3.revenue", rows: [
    [UI::Table::RawText.new("Region"), UI::Table::RawText.new("Owner"), UI::Table::RawText.new("Revenue")],
    [UI::Table::RawText.new("EMEA"), owner, UI::Table::RawNumber.new(1_250_000, "$1.25M")],
  ], column_settings: [
    UI::Table::ColumnSetting.new(is_wrapped: true),
    nil,
    UI::Table::ColumnSetting.new(align: UI::Table::ColumnAlignment::Right),
  ])
end
# {"type":"table","block_id":"q3.revenue","column_settings":[{"is_wrapped":true},null,{"align":"right"}],
#  "rows":[[{"type":"raw_text","text":"Region"},...],[...,{"type":"raw_number","value":1250000,"text":"$1.25M"}]]}
```

Slack permits up to 100 rows, 20 cells in a row, and 20 column settings. Rows can have different numbers of cells. The library also requires at least one row, at least one cell in each row, nonempty raw text, and a finite number. These checks are library policy. `DisplayModal` and `FormModal` reject `Blocks::Table` at compile time, because Slack shows tables only in messages and on Home. Slack limits the characters in all cells of a table, and of all tables in a message, to 10,000. Slack checks this limit. Received tables decode as `ReceivedBlocks::Table`; see [Read blocks from messages and views](#read-blocks-from-messages-and-views). See Slack's [table block](https://docs.slack.dev/reference/block-kit/blocks/table-block/) reference and the offline [table example](../examples/block_kit_table.cr).

### Show standard markdown

Use `Blocks::Markdown` to send standard markdown in a message, for example a reply from an LLM. Slack translates the text into its own blocks. One markdown block can become more than one block. Use `MessageBuilder#markdown`, or pass the block to `add`.

```crystal
message = UI.message(fallback_text: "How to rotate the signing secret") do |builder|
  builder.markdown("## Rotate the secret\n\n1. Open **Basic Information**.\n2. Select _Regenerate_.")
end
# {"text":"How to rotate the signing secret",
#  "blocks":[{"type":"markdown","text":"## Rotate the secret\n\n1. Open **Basic Information**.\n2. Select _Regenerate_."}]}
```

Slack limits the text of all markdown blocks in one payload to 12,000 characters. A `Blocks::Markdown` with more text, or a `Message` whose markdown blocks have more text in total, raises `ValidationError` (`markdown.text.too_long` or `message.markdown.too_long`). Send a longer answer as more than one message. Empty text is rejected by library policy. Slack ignores a `block_id` on this block and does not keep it, so `Blocks::Markdown` does not accept one. `Home`, `DisplayModal`, and `FormModal` reject `Blocks::Markdown` at compile time, because Slack shows markdown blocks only in messages. Slack checks how the markdown renders. Received messages contain Slack's translated blocks, not markdown blocks. See Slack's [markdown block](https://docs.slack.dev/reference/block-kit/blocks/markdown-block/) reference and the offline [markdown example](../examples/block_kit_markdown.cr).

### Show an alert in a modal

Use `Blocks::Alert` to show a short status in a `DisplayModal` or `FormModal`. The text is a `plain_text` or `mrkdwn` object of up to 200 characters. `level` is a `Blocks::AlertLevel`: `Default`, `Info`, `Warning`, `Error`, or `Success`. If you do not set `level`, the library does not send it, and Slack shows the default level.

```crystal
modal = UI.display_modal(title: UI.plain("Deploy 42")) do |builder|
  builder.alert(UI.mrkdwn("*Migrations* failed"), level: UI::Blocks::AlertLevel::Error, block_id: "check.migrations")
  builder.alert(UI.plain("Build passed"), level: UI::Blocks::AlertLevel::Success)
end
# {"type":"alert","block_id":"check.migrations","text":{"type":"mrkdwn","text":"*Migrations* failed"},"level":"error"}
```

Slack shows alert blocks only in modals. `Message` and `Home` reject `Blocks::Alert` at compile time with the message "Messages and Home tabs reject Alert blocks". Message and Home builders do not have an `alert` helper. Slack's field table lists `text` as a String and `level` as an Array. Slack's example and SDKs send a text object and one string, and the library does the same. An alert sends no interaction payload. See Slack's [alert block](https://docs.slack.dev/reference/block-kit/blocks/alert-block/) reference and the offline [alert example](../examples/block_kit_alert.cr).

`DisplayModalBlock` and `ModalBlock` contain `Blocks::Alert`, so `DisplayModalBlock` is not part of `MessageBlock` or `HomeBlock`. To use the same display block in a modal and a message, keep it as its concrete type (for example `Blocks::Divider`), not as a `DisplayModalBlock` value.

### Show a data table

Use `Blocks::DataTable` to show a table that Slack can page and sort, in a message or on Home. Give a `caption`, a `header`, and data `rows`. Slack receives the header as the first row. A header cell is a `Table::RawText` or a `Table::RawNumber`; the compiler rejects a `Blocks::RichText` header cell. A data cell can also be a `Blocks::RichText`.

```crystal
alias RT = Slack::UI::RichText
assignee = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::User.new("U123")})})
message = UI.message(fallback_text: "Open support tickets") do |builder|
  builder.data_table(caption: "Open support tickets", page_size: 10,
    header: {UI::Table::RawText.new("Ticket"), UI::Table::RawText.new("Assignee"), UI::Table::RawText.new("Age (days)")},
    rows: [[UI::Table::RawText.new("SUP-101"), assignee, UI::Table::RawNumber.new(3, "3")]])
end
# {"type":"data_table","caption":"Open support tickets","page_size":10,
#  "rows":[[{"type":"raw_text","text":"Ticket"},...],[{"type":"raw_text","text":"SUP-101"},...]]}
```

Slack permits 1 to 200 data rows and 1 to 20 columns. Each data row must have the same number of cells as the header. `page_size` is from 1 to 100; Slack uses 5 if you omit it. `row_header_column_index` is the 0-based column that identifies each row for screen readers; Slack uses 0 if you omit it. The library also requires a nonempty caption and a `row_header_column_index` inside the header. These two checks are library policy. Issue paths name the constructor arguments, so `rows[0]` is the first data row, not the header.

`DisplayModal` and `FormModal` reject `Blocks::DataTable` at compile time. Slack limits the characters in all cells of a data table, and of all table cells in a message, to 20,000. Slack checks this limit. Slack sorts and pages the table in the client and documents no app payload for these actions. Slack mentions interactive cells, but its reference has no schema for them, so the library does not support them. Received data tables decode as `ReceivedBlocks::DataTable`; see [Read blocks from messages and views](#read-blocks-from-messages-and-views). See Slack's [data table block](https://docs.slack.dev/reference/block-kit/blocks/data-table-block/) reference and the offline [data table example](../examples/block_kit_data_table.cr).

### Show a chart

Use `Blocks::DataVisualization` to show a pie, bar, area, or line chart in a message or on Home. Slack renders the chart. The block has a `title` and one `DataVisualization::Chart`:

- `PieChart` has `Segment` values. Each segment has a label and a value greater than 0.
- `BarChart`, `AreaChart`, and `LineChart` have `DataSeries` values and one `AxisConfig`. The categories in `AxisConfig` set the x-axis order. Each series must have exactly one `DataPoint` for each category, in any order.

```crystal
alias DV = Slack::UI::DataVisualization
message = UI.message(fallback_text: "Weekly report") do |builder|
  builder.data_visualization("Deploys by service", DV::PieChart.new({DV::Segment.new("api", 14), DV::Segment.new("web", 9)}))
  builder.data_visualization("p95 latency", block_id: "latency", chart: DV::LineChart.new(
    {DV::DataSeries.new("us-east", {DV::DataPoint.new("Mon", 120.5), DV::DataPoint.new("Tue", 98)})},
    DV::AxisConfig.new({"Mon", "Tue"}, x_label: "Day", y_label: "Latency (ms)")
  ))
end
# {"type":"data_visualization","title":"Deploys by service",
#  "chart":{"type":"pie","segments":[{"label":"api","value":14},{"label":"web","value":9}]}}
# {"type":"data_visualization","block_id":"latency","title":"p95 latency",
#  "chart":{"type":"line","series":[{"name":"us-east","data":[{"label":"Mon","value":120.5},{"label":"Tue","value":98}]}],
#           "axis_config":{"categories":["Mon","Tue"],"x_label":"Day","y_label":"Latency (ms)"}}}
```

Slack limits:

| Value | Slack limit |
| --- | --- |
| Title | 50 characters |
| Pie segments | 1 to 12; label 20 characters; value greater than 0 |
| Series in a bar, area, or line chart | 1 to 12; unique names of 20 characters |
| Data points in a series | 1 to 20; one for each category; label 20 characters; negative values are permitted |
| Categories | 20 characters each |
| `x_label`, `y_label` | 50 characters each |
| Data visualization blocks in a message | 2 |

The library also requires nonempty text, 1 to 20 unique categories, unique segment labels, and finite values. These checks are library policy. Slack's [rich response guide](https://docs.slack.dev/ai/slackbot-mcp-client/returning-rich-responses) states the uniqueness and minimum lengths; the block reference does not. The block reference examples use series names longer than 20 characters, but its field table gives 20 as the maximum. The library uses the field table.

`Message` rejects a third data visualization block. Slack does not state a count for Home, so `Home` does not check one. `DisplayModal` and `FormModal` reject `Blocks::DataVisualization` at compile time. The block has no inbound payload. Received blocks decode as `ReceivedBlocks::DataVisualization` with a raw `chart`; see [Read blocks from messages and views](#read-blocks-from-messages-and-views). Offline checks do not prove that Slack renders a chart. See Slack's [data visualization block](https://docs.slack.dev/reference/block-kit/blocks/data-visualization-block/) reference and the offline [chart example](../examples/block_kit_data_visualization.cr).

### Show cards and a carousel

Use `Blocks::Card` to show an image, a title, text, and up to three buttons. Use `Blocks::Carousel` to show 1 to 10 cards in a row that scrolls horizontally.

```crystal
card = UI::Blocks::Card.new(
  block_id: "department.mdr",
  icon: UI::CompositionObjects::SlackIcon.new(:code),
  title: UI.plain("MDR"),
  subtitle: UI::CompositionObjects::Mrkdwn.new("_Refining data files_"),
  hero_image: UI::BlockElements::Image.new(alt_text: "The MDR office", image_url: "https://example.com/mdr.png"),
  body: UI.plain("Blue badge required to gain access."),
  actions: {UI::BlockElements::Button.new(text: UI.plain("Visit"), action_id: "visit.request", value: "mdr")}
)
message = UI.message(fallback_text: "Departments open for visits") do |builder|
  builder.carousel({card}, block_id: "departments")
end
# {"type":"carousel","block_id":"departments","elements":[{"type":"card","block_id":"department.mdr",
#  "slack_icon":{"type":"icon","name":"code"},"title":{...},...,"actions":[{"type":"button",...}]}]}
```

- **Icon:** `icon:` takes an image element or a `CompositionObjects::SlackIcon`. The library sends an image element as `icon` and a Slack icon as `slack_icon`. Slack shows both in the same place and accepts only one, so you cannot send both. `SlackIconName` has the 54 documented names; for example, `:caret_left` sends `caret-left`.
- **Text:** `title`, `subtitle`, `body`, and `subtext` take `plain_text` or `mrkdwn`. Titles and subtitles have at most 150 characters; body and subtext have at most 200.
- **Content:** a card needs a `hero_image`, `title`, `actions`, or `body`. Image alt text in a card has at most 2000 characters.
- **Actions:** `actions` holds 1 to 3 `Button` elements. The library sends them as a plain array, as all of Slack's examples do. Slack's field table names an Actions block type for this field; if Slack changes the contract, this can change. To show no buttons, omit `actions`. An empty list and duplicate action IDs in one card are library policy.

`DisplayModal` and `FormModal` accept a Card. They reject `Blocks::Carousel` at compile time, because Slack shows carousels only in messages and on Home. Card block IDs must be unique in a carousel (library policy). A click on a card button sends an ordinary `block_actions` payload that decodes as `Interactions::ButtonAction`. Slack does not document which `block_id` the action carries, so match on `action_id` and `value`. Received cards and carousels decode as `ReceivedBlocks::Card` and `ReceivedBlocks::Carousel`; see [Read blocks from messages and views](#read-blocks-from-messages-and-views). See Slack's [card block](https://docs.slack.dev/reference/block-kit/blocks/card-block/), [carousel block](https://docs.slack.dev/reference/block-kit/blocks/carousel-block/), and [Slack icon object](https://docs.slack.dev/reference/block-kit/composition-objects/slack-icon-object/) references and the offline [card carousel example](../examples/block_kit_card_carousel.cr).

### Group blocks in a container

Use `Blocks::Container` to put up to 10 child blocks under a title in a message or on Home. Give a plain-text `title:`, a `rich_text_title:`, or both. The compiler rejects a container without a title. If you give both, Slack shows `rich_text_title`. Optional fields are `subtitle` (plain text or mrkdwn), `width` (`Container::Width` Narrow, Standard, Wide, or Full), `icon` (an Image element), `is_collapsible`, `default_collapsed`, `has_header_divider`, and `block_id`.

```crystal
children = [
  UI::Blocks::Section.new(text: UI.mrkdwn("*DCW-1024*\nStatus: Open → Closed"), block_id: "record.DCW-1024"),
  UI::Blocks::Actions.new(block_id: "bulk.actions", elements: {
    UI::BlockElements::Button.new(text: UI.plain("Confirm all"), action_id: "bulk.confirm"),
  }),
] of UI::Blocks::Container::Child
message = UI.message(fallback_text: "Bulk update") do |builder|
  builder.add(UI::Blocks::Container.new(title: UI.plain("Bulk update"), is_collapsible: true,
    width: UI::Blocks::Container::Width::Wide, child_blocks: children))
end
# {"type":"container","title":{"type":"plain_text","text":"Bulk update"},"width":"wide",
#  "is_collapsible":true,"child_blocks":[{"type":"section",...},{"type":"actions",...}]}
```

Child blocks can be Section, Actions, Context, Divider, File, Header, Image, Input, RichText, Table, or Video. A container cannot contain another container. The compiler rejects other child types. `Home` rejects a File child with `home.file.unsupported_surface`, because Slack shows remote file blocks in messages only; Slack does not document a File child on Home. `Home` also rejects a DatetimePicker or a WorkflowButton in a child, as it does at the top level. Block IDs of child blocks must be unique across the full message or view. One `focus_on_load: true` element is permitted in the view, including elements in child blocks.

Slack limits `title` and `subtitle` to 150 characters, `child_blocks` to 10 blocks, and icon alt text to 2000 characters. The library also requires at least one child block. This check is library policy; Slack does not document a minimum. Slack uses `default_collapsed` only when `is_collapsible` is true, and `has_header_divider` only when the container is not collapsible. The library sends these flags as you give them. `DisplayModal` and `FormModal` reject `Blocks::Container` at compile time, because Slack shows containers only in messages and on Home.

The container sends no interaction payload. A click on a button in a child block arrives as an ordinary `block_actions` payload and decodes as `ButtonAction`, with the child block's `block_id`. Slack does not document how `state.values` keys an Input in a container. This guide assumes that the key is the child Input's `block_id`, as for a top-level Input; test this with your app. Received containers decode as `ReceivedBlocks::Container` with decoded `child_blocks`; see [Read blocks from messages and views](#read-blocks-from-messages-and-views). See Slack's [container block](https://docs.slack.dev/reference/block-kit/blocks/container-block) reference and the offline [container example](../examples/block_kit_container.cr).

## Inputs

Collect values in forms. Most of these inputs are for modals only.

### Enter a number

Use `BlockElements::NumberInput` to collect a whole or decimal number in a form modal. Slack supports this element only in an Input block in a modal. Pass it to `FormModalBuilder#input`, or wrap it in `Blocks::ModalInput`. `Message`, `Home`, and `DisplayModal` do not accept it; the compiler rejects that code.

```crystal
view = UI.form_modal(title: UI.plain("Book room"), submit: UI.plain("Book")) do |builder|
  builder.input(label: UI.plain("Seats"), block_id: "seats",
    element: UI::BlockElements::NumberInput.new(
      is_decimal_allowed: false, action_id: "count",
      initial_value: "2", min_value: "1", max_value: "12"
    ))
end
```

`is_decimal_allowed` is required; read it with `decimal_allowed?`. `initial_value`, `min_value`, and `max_value` are strings, as on the wire. The library sends them unchanged, so decimal precision does not change. Other optional fields are `action_id` (255 characters), `dispatch_action_config`, `focus_on_load`, and a plain-text `placeholder` (150 characters). One element per view can request focus.

Slack requires `min_value` to be less than or equal to `max_value`. The library compares the exact decimal values. As library policy, each supplied number must be a plain decimal string, such as `-10`, `0`, or `5.5`. Exponents, a plus sign, separators, and a bare decimal point are rejected. When `is_decimal_allowed` is false, each supplied number must be whole. Slack does not document a rule for an `initial_value` outside the range, so the library does not check it.

Read `state_map.number_input_value?(block_id, action_id)` in a submission. With `dispatch_action_config` and `dispatch_action: true` on the block, Slack sends a `NumberInputAction`. Both expose `value : String?` and `value_presence` (Absent, Null, or Present). The value stays a string. Parse it and check its range in the application before you store it. Received values are not checked with outbound rules; wrong JSON types raise path-aware `TypeMismatch`.

Number input interactions decode as `NumberInputAction` and `NumberInputValue`. The [offline booking workflow](../examples/block_kit_number_input.cr) opens a number form from a signed button action, reads a dispatched number, rejects an out-of-range submission with `ModalErrors`, and accepts a corrected one.

### Collect uploaded files

Use `BlockElements::FileInput` to let a user attach files to a form. Slack accepts it only in an Input block in a modal, so it is a `Blocks::ModalInput` child, like NumberInput. Pass it to `FormModalBuilder#input`, or wrap it in `Blocks::ModalInput`. `Message`, `Home`, and `DisplayModal` do not accept it; the compiler rejects that code.

```crystal
view = UI.form_modal(title: UI.plain("Expense"), submit: UI.plain("Send")) do |builder|
  builder.input(label: UI.plain("Receipts"), block_id: "receipts",
    element: UI::BlockElements::FileInput.new(
      action_id: "files", filetypes: {"pdf", "png"}, max_files: 3
    ))
end
```

FileInput supports optional `action_id` (255 characters), `filetypes`, and `max_files` from 1 through 10. Slack accepts all extensions when you omit `filetypes` and allows 10 files when you omit `max_files`. The library rejects an empty `filetypes` list and blank extensions; omit the field to accept all. The element copies `filetypes` once, and the getter returns a copy. Slack does not dispatch block actions for this element, so a `ModalInput` that holds FileInput rejects `dispatch_action: true`. See Slack's [file input](https://docs.slack.dev/reference/block-kit/block-elements/file-input-element/) reference.

The `filetypes` filter is a convenience. Check each received file in the application. Your app needs the `files:read` scope, and Slack applies a 100MB file size limit. The library does not check these remote conditions or download files.

Read `state_map.file_input_value?` with the block and action IDs. `files` returns `Array(UploadedFile)?`, and `files_presence` distinguishes Absent, Null, and Present (an empty array is Present). Each `UploadedFile` has a required `id` and optional `name`, `title`, `mimetype`, `filetype`, `url_private`, and `url_private_download`, and an optional `size` in bytes (`Int64?`). Other file fields stay in `raw`. Wrong JSON types raise path-aware `TypeMismatch`. A `file_input` entry in `actions` stays `UnknownAction`.

```crystal
if value = submission.state_map.file_input_value?("receipts", "files")
  ids = value.files.try(&.map(&.id)) || [] of String
end
```

`file_input` state entries decode as `FileInputValue`, and `Blocks::ModalInputElement` includes FileInput. The [offline upload workflow](../examples/block_kit_file_input.cr) opens a receipt form from a signed button action and reads the uploaded file IDs from a signed submission. It does not prove upload completion, file access, or remote acceptance.

### Enter a URL

Use `BlockElements::UrlInput` (wire type `url_text_input`) to collect a link in a form modal. Slack supports this element only in an Input block in a modal. Pass it to `FormModalBuilder#input`, or wrap it in `Blocks::ModalInput`. `Message`, `Home`, and `DisplayModal` do not accept it; the compiler rejects that code.

```crystal
view = UI.form_modal(title: UI.plain("Report a bug"), submit: UI.plain("Send")) do |builder|
  builder.input(label: UI.plain("Page link"), block_id: "bug.link",
    element: UI::BlockElements::UrlInput.new(action_id: "page", placeholder: UI.plain("https://")))
end
```

All fields are optional: `action_id` (255 characters), `initial_value`, `dispatch_action_config`, `focus_on_load`, and a plain-text `placeholder` (150 characters). One element per view can request focus. Slack does not document a format rule for `initial_value`, so the library sends it unchanged.

Read `state_map.url_input_value?(block_id, action_id)` in a submission. With `dispatch_action_config` and `dispatch_action: true` on the block, Slack sends a `UrlInputAction`. Both expose `value : String?` and `value_presence` (Absent, Null, or Present). Slack checks that the entry is a URL. Application rules, such as HTTPS only or an allowed host, stay in the application. Do not fetch a received URL without your own checks.

URL input interactions decode as `UrlInputAction` and `UrlInputValue`. The [offline bug report workflow](../examples/block_kit_url_input.cr) opens a form from a signed button action, reads a dispatched link, rejects an HTTP link with `ModalErrors`, and accepts an HTTPS link.

### Enter an email address

Use `BlockElements::EmailInput` to collect one email address in a form modal. Slack supports this element only in an Input block in a modal. Pass it to `FormModalBuilder#input`, or wrap it in `Blocks::ModalInput`. `Message`, `Home`, and `DisplayModal` do not accept it; the compiler rejects that code.

```crystal
view = UI.form_modal(title: UI.plain("Invite a guest"), submit: UI.plain("Invite")) do |builder|
  builder.input(label: UI.plain("Guest email"), block_id: "invite",
    element: UI::BlockElements::EmailInput.new(
      action_id: "email", placeholder: UI.plain("name@partner.example")
    ))
end
```

All fields are optional: `action_id` (255 characters), `initial_value`, `dispatch_action_config`, `focus_on_load`, and a plain-text `placeholder` (150 characters). One element per view can request focus. Slack documents no address syntax rule for `initial_value`, so the library sends it unchanged.

Read `state_map.email_input_value?(block_id, action_id)` in a submission. With `dispatch_action_config` and `dispatch_action: true` on the block, Slack sends an `EmailInputAction`. Both expose `value : String?` and `value_presence` (Absent, Null, or Present). The library does not check the received address. Apply your own rules, such as an allowed domain, and return `ModalErrors` for a bad value. Wrong JSON types raise path-aware `TypeMismatch`.

Email input interactions decode as `EmailInputAction` and `EmailInputValue`. The [offline invitation workflow](../examples/block_kit_email_input.cr) opens an email form from a signed button action, reads a dispatched address, rejects an address outside the allowed domain with `ModalErrors`, and accepts a corrected one.

### Enter formatted text

Use `BlockElements::RichTextInput` to collect formatted text in a form modal or on Home. Slack supports this element only in an Input block in a modal or a Home tab. Pass it to `FormModalBuilder#input` or `HomeBuilder#input`, or wrap it in `Blocks::ViewInput`. `Message` and `DisplayModal` do not accept it; the compiler rejects that code.

```crystal
draft = UI::Blocks::RichText.new(elements: {
  UI::RichText::Section.new(elements: {UI::RichText::Text.new("Yesterday: ")}),
})
home = UI.home do |builder|
  builder.input(label: UI.plain("Standup"), block_id: "standup",
    element: UI::BlockElements::RichTextInput.new(
      action_id: "summary", initial_value: draft, max_lines: 12
    ))
end
```

Slack requires `action_id` (255 characters) for this element. As library policy, it must not be empty. `initial_value` is a `Blocks::RichText`; see [Show rich text](#show-rich-text). Other optional fields are `dispatch_action_config`, `focus_on_load`, a plain-text `placeholder` (150 characters), `min_lines`, and `max_lines`. Each line count must be from 1 to 100. Slack documents no rule between the two counts, so the library does not compare them. Slack also lists the Table block as a parent; the library does not support that placement.

Read `state_map.rich_text_input_value?(block_id, action_id)` in a submission or a Home action. With `dispatch_action_config` and `dispatch_action: true` on the block, Slack sends a `RichTextInputAction`. Both expose `rich_text_value : Slack::Interactions::RichText::Block?` and `value_presence` (Absent, Null, or Present). The received tree uses the parser from [Show rich text](#show-rich-text), without outbound rules. A malformed tree or a wrong JSON type raises `TypeMismatch` with the JSON path, and `raw` keeps the complete JSON.

```crystal
case action = interaction.decoded_actions.first
when Slack::Interactions::RichTextInputAction
  if tree = action.rich_text_value
    tree.elements.each do |container|
      next unless container.is_a?(Slack::Interactions::RichText::Section)
      container.elements.each do |element|
        puts element.text if element.is_a?(Slack::Interactions::RichText::Text)
      end
    end
  end
end
```

Rich text input interactions decode as `RichTextInputAction` and `RichTextInputValue`. The [offline standup workflow](../examples/block_kit_rich_text_input.cr) publishes a Home composer with a draft, reads text and mentions from a signed dispatched action, and skips a malformed tree.

## Modals and Home

Open, update, and push modals, publish Home, and answer submissions.

### Build modals and Home

Use `form_modal` for input and `display_modal` for display content. Both have a plain-text title; a form has a required plain-text submit label. A modal can have at most 100 blocks. For a form:

```crystal
alias UI = Slack::UI
view = UI.form_modal(title: UI.plain("Request reason"), submit: UI.plain("Save")) do |builder|
  builder.input(label: UI.plain("Reason"), block_id: "reason", optional: true,
    element: UI::BlockElements::PlainTextInput.new(action_id: "text", multiline: true))
end

opened = client.call(Slack::Api::ViewsOpen.new(trigger_id: trigger_id, view: view))
```

The open request needs a trigger ID from the interaction and places `external_id` inside the view. A Home view has no title or submit. Its builder accepts the same display blocks and Input. An empty Home is valid; the local maximum is 100 blocks. Publishing needs a user ID. An optional `hash` helps avoid overwriting a newer Home; Slack validates the remote hash and external ID uniqueness.

```crystal
alias UI = Slack::UI
home = UI.home(callback_id: "projects") do |builder|
  builder.header(text: UI.plain("Your projects"), level: 1)
  builder.context(elements: {UI.mrkdwn("*Project 42*"), UI.plain("Ready for review")})
end

published = client.call(Slack::Api::ViewsPublish.new(user_id: user_id, view: home))
```

Enable the Home tab and install the app with the permissions required for publishing. The publish response exposes the returned view as raw JSON. Slack remains responsible for server access checks and rendering.

### Update a modal

Use `ViewsUpdate` with a `FormModal` or `DisplayModal` to replace an existing modal view. The supported request fields are `view`, `view_id`, `external_id`, and optional `hash`. Home updates use `ViewsPublish`; the [modal reference](https://docs.slack.dev/reference/views/modal-views/) lists `views.update`, while the [Home reference](https://docs.slack.dev/reference/views/home-tab-views/) lists `views.publish`.

```crystal
updated_view = UI.form_modal(title: UI.plain("Request reason"), submit: UI.plain("Save")) do |builder|
  builder.section(UI.plain("Add details before saving."))
  builder.input(label: UI.plain("Reason"), block_id: "reason", optional: true,
    element: UI::BlockElements::PlainTextInput.new(action_id: "text", multiline: true))
end
updated = client.call(Slack::Api::ViewsUpdate.new(
  view_id: opened.view["id"].as_s, hash: opened.view["hash"].as_s, view: updated_view
))
```

Supply exactly one nonblank target: `view_id:` from Slack or the developer's `external_id:`. This unambiguous selector rule is library policy, not a claim that Slack rejects both. The external selector allows up to 255 characters. A view's nested `external_id` remains metadata: it never supplies, replaces, or overrides the top-level selector. To target a developer ID, use `external_id: "request-42"` instead of `view_id:`. The nested view may have its own independent external ID.

`hash` is optional and opaque. Omission and an explicit empty string stay distinct; the adapter sends supplied hashes unchanged. Slack checks remote view existence, hash freshness, external ID uniqueness, and access. `not_found` and `hash_conflict` raise `Slack::Api::Error` through `Client#call`; the adapter does not retry or merge conflicts. See the [method reference](https://docs.slack.dev/reference/methods/views.update/).

Keep each retained input's `block_id` and `action_id` identical to the old view so Slack can preserve entered values. The adapter does not have the old view and cannot validate those matches or migrate state. The [offline open/update workflow](../examples/block_kit_view_update.cr) checks transmitted IDs, not live state preservation. Slack's [modal update guide](https://docs.slack.dev/surfaces/modals/#updating-modal-views) explains input state and hash conflicts.

The constructor owns a view snapshot. JSON serialization and `Client#call` validate local values before transport. `call` returns `Slack::Models::ViewsUpdate`, exposing `ok?` and raw `view` JSON, including returned IDs, hash, state, and unknown fields. Existing modal placement and submit rules apply. Pushing uses `ViewsPush`; typed error acknowledgments use `ModalErrors`.

### Push the next modal view

Use `ViewsPush` with a `FormModal` or `DisplayModal` and a fresh `trigger_id` from an interaction **inside the existing modal**. The supported JSON fields are exactly `trigger_id` and `view`; `external_id`, callback ID, private metadata, and modal flags stay inside `view`. There is no top-level view selector or hash. The alternate `interactivity_pointer` mechanism is unsupported.

```crystal
# interaction is a BlockAction from Slack::Interactions.parse after verification.
trigger = interaction.trigger_id || raise "Missing modal trigger"
next_view = UI.form_modal(title: UI.plain("Details"), submit: UI.plain("Save"),
  close: UI.plain("Back"), private_metadata: "42") do |builder|
  builder.input(label: UI.plain("Reason"), block_id: "reason",
    element: UI::BlockElements::PlainTextInput.new(action_id: "text"))
end
pushed = client.call(Slack::Api::ViewsPush.new(trigger_id: trigger, view: next_view))
```

The constructor owns a modal snapshot and preserves the existing FormModal submit and DisplayModal placement rules. Serialization and `Client#call` validate local values before transport. A nonblank trigger is library policy; its format is opaque. `call` sends once and returns `Slack::Models::ViewsPush` with `ok?` and raw `view` JSON.

Slack permits three views in a stack, including the root view. Use the new interaction trigger promptly: triggers expire after three seconds and can be exchanged only once. Acknowledge the interaction separately within Slack's response window. The adapter does not track stack depth, verify trigger age or origin, or automatically retry. API failures such as `expired_trigger_id`, `exchanged_trigger_id`, and `push_limit_reached` raise `Slack::Api::Error` through `Client#call`. See the [method contract](https://docs.slack.dev/reference/methods/views.push/), [modal fields](https://docs.slack.dev/reference/views/modal-views/), and [modal lifecycle guide](https://docs.slack.dev/surfaces/modals/).

The [offline push workflow](../examples/block_kit_view_push.cr) opens a modal, reads a synthetic button interaction from that view, and pushes a form with the fresh trigger. It demonstrates payloads and application flow, not live trigger viability, stack state, permissions, rendering, or handler timing.

### Return modal validation errors

Use `Slack::Interactions::ModalErrors` to acknowledge a `view_submission` with errors. Its `Hash(String, String)` maps Input **block IDs**, not action IDs, to plain-text messages. Slack keeps the view open so the user can correct the input and resubmit. See [Slack's error response guidance](https://docs.slack.dev/surfaces/modals/#display-errors-in-views).

In an HTTP handler with `context : HTTP::Server::Context`, verify the original request before reading state. Route to the expected form by its callback ID, then apply the application's validation:

```crystal
case interaction = Slack::Interactions.parse(verifier.verify(context.request).body)
when Slack::Interactions::ViewSubmission
  view = interaction.view
  if view && view["callback_id"].as_s == "request.reason"
    reason = interaction.plain_text?("request.reason", "reason")
    context.response.status_code = 200
    if reason.nil? || reason.strip.size < 10
      errors = Slack::Interactions::ModalErrors.new({
        "request.reason" => "Explain why you need this request (at least 10 characters).",
      })
      context.response.content_type = "application/json"
      context.response.print(errors.to_json)
    end
    # For valid input, save it in the application and leave the HTTP 200 body empty.
  end
end
```

The route must verify the request with a `Slack::Webhooks::Verifier` and handle other callbacks, interaction types, and verification failures. Return the acknowledgment within Slack's three-second window. An empty HTTP 200 acknowledgment closes the submitted view. The library does not send the acknowledgment or enforce its deadline.

`ModalErrors` copies the supplied map; `errors` returns a copy. Construction rejects an empty map or blank messages with `Slack::UI::ValidationError`. These are library policies so the response contains useful feedback. `validate` and `validate!` use the existing validation conventions. No message length or block-ID format restriction is added. The application owns business rules and must ensure each key identifies an Input block in the submitted view; no original modal is required or checked.

This outbound value needs no token and makes no API request. It is separate from `views.update` and API failure responses. The [offline example](../examples/block_kit_modal_errors.cr) verifies signed invalid and corrected submissions and prepares their HTTP responses. Ordinary consumer specs check the complete error body and JSON content type; they do not prove live rendering or handler timing.

### Close the modal stack after submission

Use `Slack::Interactions::ModalClear.new.to_json` as the body of an HTTP 200 JSON response to a successful `view_submission`:

```crystal
response = HTTP::Client::Response.new(200,
  headers: HTTP::Headers{"Content-Type" => "application/json"},
  body: Slack::Interactions::ModalClear.new.to_json)
# Body: {"response_action":"clear"}
```

The application must send the response within three seconds. `clear` closes **all views** in the modal stack. An empty HTTP 200 instead closes only the submitted view and reveals the previous view, if one exists. See [Slack's closing guidance](https://docs.slack.dev/surfaces/modals/#closing-views).

`ModalClear` has no options, needs no token, and makes no API request. The [offline clear example](../examples/block_kit_modal_clear.cr) verifies a synthetic signed submission, accepts its input, and prepares the response. Consumer specs independently check its exact body and content type; they do not prove live closure, rendering, or acknowledgment timing.

### Push a view in a submission acknowledgment

Use `Slack::Interactions::ModalPush.new(view: next_view)` after verifying and routing a `view_submission`. It accepts a `FormModal` or `DisplayModal` and serializes `response_action: "push"` with the new `view`. Return that JSON as the HTTP 200 acknowledgment within three seconds. See [Slack's push acknowledgment guidance](https://docs.slack.dev/surfaces/modals/#add-a-new-view-via-response_action).

```crystal
# In the handler for a verified and routed view_submission:
next_view = UI.form_modal(title: UI.plain("Delivery details"), submit: UI.plain("Save"),
  close: UI.plain("Back"), callback_id: "request.delivery", private_metadata: "42") do |builder|
  builder.input(label: UI.plain("Delivery note"), block_id: "delivery",
    element: UI::BlockElements::PlainTextInput.new(action_id: "note", multiline: true))
end
acknowledgment = Slack::Interactions::ModalPush.new(view: next_view)
context.response.status_code = 200
context.response.content_type = "application/json"
context.response.print(acknowledgment.to_json)
```

`ModalPush` owns a modal snapshot; `view` returns a snapshot. Existing placement, submit, focus, and validation rules apply. `validate` and `validate!` use the validation conventions. Callback ID, private metadata, `external_id`, and flags stay inside `view`; Slack checks external-ID uniqueness. `submit_disabled` remains specific to configuration modals.

The application owns HTTP delivery and timing. This value needs no token or trigger and makes no Web API call. Slack owns the stack and permits at most three views; the library does not track stack depth, retry, or enforce the deadline. For a button interaction inside a modal, use the separate `ViewsPush` API adapter described above.

The [offline submission-push example](../examples/block_kit_modal_push.cr) verifies an independently authored signed submission, reads its reason and metadata, and returns the next form as HTTP 200 JSON. Its consumer spec checks the complete acknowledgment body. Offline checks do not prove live stack state, Slack acceptance, rendering, or response timing.

### Update a modal in its submission acknowledgment

Use `Slack::Interactions::ModalUpdate` to replace the currently visible submitted view. Pass an existing `FormModal` or `DisplayModal`; the acknowledgment owns a snapshot and `view` returns a snapshot. Existing modal validation, placement, and submit rules apply. `validate` and `validate!` use the validation conventions.

```crystal
updated_view = UI.form_modal(title: UI.plain("Review request"), submit: UI.plain("Save"),
  callback_id: "request.review") do |builder|
  builder.section(UI.plain("Choose an owner before saving."))
  builder.input(label: UI.plain("Reason"), block_id: "request.reason",
    element: UI::BlockElements::PlainTextInput.new(action_id: "reason", multiline: true))
  builder.input(label: UI.plain("Owner"), block_id: "request.owner",
    element: UI::BlockElements::UsersSelect.new(action_id: "owner"))
end
acknowledgment = Slack::Interactions::ModalUpdate.new(updated_view)
# In the application's verified view_submission route:
context.response.status_code = 200
context.response.content_type = "application/json"
context.response.print(acknowledgment.to_json)
```

The JSON contains only `response_action: "update"` and `view`. Modal metadata, including `external_id`, stays inside `view`. This acknowledgment needs no token, target selector, trigger, or hash and performs no API call. `ViewsUpdate` is the separate Web API operation for updating a selected view.

Verify the original signed request with `Slack::Webhooks::Verifier`, parse it with `Slack::Interactions.parse`, route the expected `ViewSubmission` callback, and return HTTP 200 JSON within three seconds. The application owns response delivery, timing, and handling later submissions. Keep retained input `block_id` and `action_id` values stable. No previous modal is required, so the library cannot check ID matches or preserve remote input state itself. See [Slack's update acknowledgment guidance](https://docs.slack.dev/surfaces/modals/#update-a-view-via-response_action) and [modal fields](https://docs.slack.dev/reference/views/modal-views/).

The [offline example](../examples/block_kit_modal_update.cr) verifies a signed submission, reads its reason, and prepares an updated form with the same reason input IDs and a new owner select. Its consumer spec checks the complete HTTP 200 JSON response; it does not prove live Slack acceptance, rendering, state preservation, or timing.

## Received blocks

Read the blocks of messages and views that Slack sends. To read actions, state, and interaction context, see [Events and interactions](events-and-interactions.md#interactions). To answer slash commands and post to a `response_url`, see [Slash commands](events-and-interactions.md#slash-commands) and [Reply through a response URL](events-and-interactions.md#reply-through-a-response-url).

### Read blocks from messages and views

Slack sends the blocks of a message or view in events and interactions. These getters decode them as `Array(Slack::Interactions::ReceivedBlock)`:

- `Slack::Events::Message#blocks`, `Message::FileShare#blocks`, and `EventData::MessageSubset#blocks` (the `message` and `previous_message` of `Message::MessageChanged` and `Message::MessageDeleted`).
- `ReceivedMessage#blocks` from `BlockAction#message` and `MessageAction#message`.
- `View#blocks` from `BlockAction#view`, `ViewSubmission#view`, and `ViewClosed#view`.

`ReceivedBlock` is a union of one struct for each block type. The types are in `Slack::Interactions::ReceivedBlocks`: `Section`, `Actions`, `Context`, `ContextActions`, `Divider`, `Header`, `Image`, `Input`, `Markdown`, `File`, `Video`, `Table`, `DataTable`, `Container`, `Card`, `Carousel`, `Alert`, `DataVisualization`, `Plan`, `TaskCard`, and `UnknownBlock`. A `rich_text` block decodes as `Slack::Interactions::RichText::Block` (see [Show rich text](#show-rich-text)).

- Each block has `raw`, the complete JSON, and each known block has `block_id`.
- Text objects decode as `ReceivedText` with `type`, `text`, `emoji`, and `verbatim`.
- Elements in `Actions`, `ContextActions`, a Section `accessory`, an Input `element`, and Card images and actions decode as `ElementSummary` with `type`, `action_id`, and `raw`. Read selected values from the action payload or `state_map`, not from the block.
- `Context` elements are `ReceivedText` or `ElementSummary` (images).
- `Card#slack_icon` is a `ReceivedBlocks::SlackIcon?` with `name`. It is not an `ElementSummary`. Replace `card.slack_icon.try(&.raw["name"].as_s)` with `card.slack_icon.try(&.name)`. An icon without `name` raises `TypeMismatch`.
- `TaskCard#sources` is an `Array(TaskCard::Source)`, each with `type`, `url`, and `text`. It is empty when `sources` is absent or null.
- `Table` and `DataTable` rows hold `RawText`, `RawNumber` (`value` is `Int64` or `Float64`), `RichText::Block`, or `UnknownBlock` cells.
- `Container#child_blocks` and `Carousel#elements` decode like top-level blocks.
- `DataVisualization#chart`, `Plan#tasks`, `Table#column_settings`, and `Image#slack_file` stay raw JSON. For other fields, such as a task card's `details`, read `raw`.
- A block type that this library does not read decodes as `UnknownBlock` with `type` and `raw`.

```crystal
case interaction = Slack::Interactions.parse(verifier.verify(request).body)
when Slack::Interactions::BlockAction
  if message = interaction.message
    message.blocks.each do |block|
      case block
      when Slack::Interactions::ReceivedBlocks::Section
        puts block.text.try(&.text)
      when Slack::Interactions::ReceivedBlocks::Actions
        puts block.elements.compact_map(&.action_id).join(", ")
      when Slack::Interactions::ReceivedBlocks::UnknownBlock
        puts "Skipped #{block.type}"
      end
    end
  end
end
```

The getters decode on the first call, keep the result, and return an empty array when blocks are absent or null. A getter such as `ctx.event` returns a copy of the event, and a copy made before the first call decodes again. To decode once, put the event in a variable and read `blocks` from that variable. A missing required field or a wrong JSON type in a known block raises `TypeMismatch` with the JSON path, such as `event.blocks[2].text`. The event or interaction itself still decodes. Received blocks do not apply outbound rules, such as length limits or placement, because Slack can send blocks from other apps or other versions.

Received blocks are read-only. They do not convert to `Slack::UI` values. To send a changed message, build a new message with `Slack::UI`. `conversations.history` messages keep raw blocks.

The [offline example](../examples/received_blocks.cr) reads the blocks of a clicked message, including container children and an unknown block type.

## Validation, limits, and ownership

Constructors check supported local values, and the complete surface checks placement, block IDs, and cross-block rules. `validate` returns `Array(ValidationIssue)`; `validate!` raises `ValidationError`. Each issue has a code, field path, and message.

```crystal
begin
  Slack::UI::Blocks::Divider.new(block_id: "x" * 256)
rescue error : Slack::UI::ValidationError
  puts error.issues.first.path # block_id
end
```

Text and field lengths count characters. Common limits: top-level Message 50 blocks, modal/Home 100 blocks, Actions 25 elements, Context 10 elements, a Section 10 fields, block/action IDs 255 characters, Header text 150, and modal title/submit/close labels 24. PlainTextInput supports `min_length`, `max_length`, multiline, and dispatch settings. View surfaces permit only one `focus_on_load: true` element across Section, Actions, and Input, including those in a Container. These checks do not prove Slack will accept a remote payload or image.

Constructors and builders accept arrays, tuples, and custom enumerables according to the **types actually yielded by `each`**. A broad declared `Enumerable(T?)` is allowed if its `each` yields only supported `T` values. Unsupported yielded values cause a compile error; constructors do no runtime filtering. Inputs are traversed once and copied into owned typed arrays. Getters return snapshots, so changing a caller array, a getter result, or a builder cannot mutate an already built surface or endpoint request.

Use a collection typed for the destination surface. An ordinary `Array(Slack::UI::MessageBlock)` has an item union that includes Input, File, Table, DataVisualization, Carousel, Container, Markdown, and ContextActions; it cannot be passed to `DisplayModal` even if its present elements happen to be display blocks. Use `Array(Slack::UI::DisplayModalBlock)` for that surface. An `Array(Slack::UI::DisplayModalBlock)` includes Alert, so it cannot be passed to `Message` or `Home`.

## Offline examples

From a repository checkout, run `shards install`, then `crystal run examples/<name>.cr`. The examples use synthetic credentials and stubbed HTTP; they do not contact Slack. They do not prove that Slack accepts or shows a payload, or that a handler answers within Slack's response window.

| Example | Shows |
| --- | --- |
| [`block_kit_message.cr`](../examples/block_kit_message.cr) | Builds and prints a message request |
| [`block_kit_message_update.cr`](../examples/block_kit_message_update.cr) | Replaces a posted approval button with the completed status and new fallback text |
| [`attachments.cr`](../examples/attachments.cr) | A message with a colored attachment and metadata |
| [`ephemeral_reply.cr`](../examples/ephemeral_reply.cr) | An ephemeral thread reply with a permalink and a scheduled reminder |
| [`block_kit_remote_file.cr`](../examples/block_kit_remote_file.cr) | The unfurls value for an application's own `chat.unfurl` request |
| [`block_kit_overflow.cr`](../examples/block_kit_overflow.cr) | Action and URL choices, and a signed URL selection |
| [`block_kit_checkboxes.cr`](../examples/block_kit_checkboxes.cr) | Initial choices, a signed checkbox action, and a cleared selection in a submission |
| [`block_kit_radio_buttons.cr`](../examples/block_kit_radio_buttons.cr) | An initial choice, a signed selection, and an unselected submission |
| [`block_kit_static_select.cr`](../examples/block_kit_static_select.cr) | A single choice, a signed selection, and a grouped multi-choice form |
| [`block_kit_users_select.cr`](../examples/block_kit_users_select.cr) | An owner assignment and a submission with several reviewers |
| [`block_kit_channels_select.cr`](../examples/block_kit_channels_select.cr) | Notification channels chosen in a form |
| [`block_kit_conversations_select.cr`](../examples/block_kit_conversations_select.cr) | Filtered conversation choices and a submission |
| [`block_kit_date_time_pickers.cr`](../examples/block_kit_date_time_pickers.cr) | Date and time choices read as strings |
| [`block_kit_datetime_picker.cr`](../examples/block_kit_datetime_picker.cr) | An instant read as Unix seconds |
| [`block_kit_external_select.cr`](../examples/block_kit_external_select.cr) | A signed options-load request answered, then a signed selection and submission |
| [`block_kit_context_actions.cr`](../examples/block_kit_context_actions.cr) | An answer with feedback and delete buttons, and a signed feedback click |
| [`block_kit_workflow_button.cr`](../examples/block_kit_workflow_button.cr) | Incident workflow buttons with trigger inputs, and a local rejection on Home |
| [`block_kit_video.cr`](../examples/block_kit_video.cr) | A video block, and a local rejection of an HTTP video link |
| [`block_kit_rich_text.cr`](../examples/block_kit_rich_text.cr) | Formatted release notes, and the mentions and lists of a signed message event |
| [`block_kit_table.cr`](../examples/block_kit_table.cr) | A revenue table, and a local rejection of a row with too many cells |
| [`block_kit_markdown.cr`](../examples/block_kit_markdown.cr) | An LLM answer as markdown, and a local rejection of text that is too long |
| [`block_kit_alert.cr`](../examples/block_kit_alert.cr) | A deploy status modal with one alert for each check |
| [`block_kit_data_table.cr`](../examples/block_kit_data_table.cr) | A paged ticket table, and a local rejection of a row narrower than the header |
| [`block_kit_data_visualization.cr`](../examples/block_kit_data_visualization.cr) | Deploy and latency charts, and a local rejection of a series with a missing category |
| [`block_kit_card_carousel.cr`](../examples/block_kit_card_carousel.cr) | Department cards and a signed card button click |
| [`block_kit_container.cr`](../examples/block_kit_container.cr) | A collapsible bulk update and a signed click inside the container |
| [`block_kit_number_input.cr`](../examples/block_kit_number_input.cr) | A modal-only number form, a dispatched value, and a rejected then accepted submission |
| [`block_kit_file_input.cr`](../examples/block_kit_file_input.cr) | A receipt form and the uploaded file IDs |
| [`block_kit_url_input.cr`](../examples/block_kit_url_input.cr) | A modal-only URL form opened from a button, and the submission acknowledgments |
| [`block_kit_email_input.cr`](../examples/block_kit_email_input.cr) | A modal-only email form, a dispatched value, and a rejected then accepted submission |
| [`block_kit_rich_text_input.cr`](../examples/block_kit_rich_text_input.cr) | A Home standup composer and a signed dispatched action |
| [`block_kit_modal.cr`](../examples/block_kit_modal.cr) | A posted button, a signed action that opens a form, and a signed submission |
| [`block_kit_modal_update.cr`](../examples/block_kit_modal_update.cr) | An updated form returned in a submission acknowledgment |
| [`block_kit_modal_push.cr`](../examples/block_kit_modal_push.cr) | A view pushed in a submission acknowledgment |
| [`block_kit_modal_errors.cr`](../examples/block_kit_modal_errors.cr) | Validation errors returned for a submission |
| [`block_kit_modal_clear.cr`](../examples/block_kit_modal_clear.cr) | The modal stack closed after a submission |
| [`block_kit_view_update.cr`](../examples/block_kit_view_update.cr) | A modal opened, then updated with `views.update` |
| [`block_kit_view_push.cr`](../examples/block_kit_view_push.cr) | A view pushed with `views.push` |
| [`block_kit_home.cr`](../examples/block_kit_home.cr) | Home published through a stub, and simulated state |
| [`received_blocks.cr`](../examples/received_blocks.cr) | The typed blocks of a clicked message |
