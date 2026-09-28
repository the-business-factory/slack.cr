# Checked Block Kit

Use `require "slack"` and `Slack::UI::Checked` to construct validated, immutable outbound values. Construction and JSON inspection need no Slack credentials. Sending needs a token with the relevant Slack API scope, and signed interaction handling needs the app signing secret. The [README](../README.md) has a complete message example and commands for offline workflows.

## Supported surfaces and placement

| Checked surface | Direct blocks | Input children | Send with |
| --- | --- | --- | --- |
| `Message` | Section, Actions, Divider, Header, Context, Image, Video, File, RichText, Table, DataTable, DataVisualization, Markdown, ContextActions, Input | PlainTextInput, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker, DatetimePicker | `Slack::Api::CheckedChatPostMessage`, `Slack::Api::CheckedChatUpdate` |
| `DisplayModal` | Section, Actions, Divider, Header, Context, Image, Video, RichText, Alert | None, even if a submit label is supplied | `Slack::Api::CheckedViewsOpen`, `Slack::Api::CheckedViewsUpdate`, `Slack::Api::CheckedViewsPush` |
| `FormModal` | Section, Actions, Divider, Header, Context, Image, Video, RichText, Alert, Input, ModalInput, ViewInput | PlainTextInput, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker, DatetimePicker; NumberInput, FileInput, UrlInput, and EmailInput through ModalInput; RichTextInput through ViewInput | `Slack::Api::CheckedViewsOpen`, `Slack::Api::CheckedViewsUpdate`, `Slack::Api::CheckedViewsPush` |
| `Home` | Section, Actions, Divider, Header, Context, Image, Video, RichText, Table, DataTable, DataVisualization, Input, ViewInput | PlainTextInput, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker; RichTextInput through ViewInput | `Slack::Api::CheckedViewsPublish` |

`FormModal` always needs a plain-text `submit` label, including forms without Input. `DisplayModal` cannot contain Input. Message and Home need no submit label. A Message can contain Input even though older phase notes excluded it. [Slack's Input reference](https://docs.slack.dev/reference/block-kit/blocks/input-block.md) lists Messages, Modals, and Home. Some Input children are modal-only in Slack. `Blocks::ModalInput` holds these children; only `FormModal` accepts it. Other children are for modals and Home only. `Blocks::ViewInput` holds these children; only `FormModal` and `Home` accept it.

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
| Input element | PlainTextInput, StaticSelect, MultiStaticSelect, ExternalSelect, MultiExternalSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect, ConversationsSelect, MultiConversationsSelect, DatePicker, TimePicker, DatetimePicker (not Home) |
| ModalInput element (FormModal only) | NumberInput, FileInput, UrlInput, EmailInput |
| ViewInput element (FormModal and Home only) | RichTextInput |

Checked Header, Context, Image, Video, and RichText blocks are display content on all four surfaces. A File block is a message-only representation. Table, DataTable, and DataVisualization blocks are for messages and Home only. Markdown and ContextActions blocks are for messages only. An Alert block is for modals only. An Image block or element needs alt text and exactly one public `image_url` or `SlackFile` source. `SlackFile` takes an ID or URL. Remote image availability and file access are checked by Slack. Section supports text, fields, and the listed accessory; Actions checks duplicate supplied action IDs within that block.

Static choices use plain-text `Option` values, optional `OptionGroup` values, and exactly one `options:` or `option_groups:` source. `StaticSelect` has one `initial_option`; `MultiStaticSelect` has `initial_options` and optional `max_selected_items`. Choice values must be unique within a menu, and initial selections must match offered options. Each group can contain up to 100 options. These two types use a **static** source. User, channel, and conversation selects use Slack-provided lists. External selects load options from your app; see [Load options from your app](#load-options-from-your-app).

Placeholder or mutable types elsewhere in the library do not extend the checked placement matrix. The checked endpoints cover only their documented request fields; they are not complete wrappers for every Slack method field or view lifecycle action.

The machine-readable [support manifest](../spec/support/block_kit/support.yml) records detailed wire fields, upstream references, and repository evidence. Evidence paths in it are relative to the repository root.

## Build and send a message

Give a message an explicit top-level fallback for screen readers. `message_with_slack_generated_fallback` omits top-level text and asks Slack to derive it; the library does not create a partial summary. The local message limit is 50 blocks. Supplied block IDs must be unique.

```crystal
require "slack"

alias UI = Slack::UI::Checked
message = UI.message(fallback_text: "Request 42 needs approval.") do |builder|
  builder.section(UI.mrkdwn("*Request 42* needs approval"))
  builder.actions(elements: [UI::BlockElements::Button.new(
    text: UI.plain("Approve"), action_id: "request.approve", value: "42",
    accessibility_label: "Approve request 42"
  )])
end

request = Slack::Api::CheckedChatPostMessage.new(
  token: ENV["SLACK_BOT_TOKEN"], channel: ENV["SLACK_CHANNEL_ID"],
  message: message
)
puts request.to_pretty_json
response = request.call
```

`CheckedChatPostMessage` accepts `channel`, checked `text`/`blocks`, `thread_ts`, `reply_broadcast`, `unfurl_links`, and `unfurl_media`. It copies and validates the message before dispatch and requires a `String` token. `result` and `call` share the same validation boundary. Named `configuration`, `transport`, and `limiter` options can customize dispatch; they are not JSON fields. The wrapper sends through the existing API client and raises `Slack::Api::Error` for API failures. It does not support every `chat.postMessage` field.

## Build a remote file block

A File block shows a remote file. Slack does not let apps add this block to messages directly. To share a remote file, the app adds it with `files.remote.add` and shares it with `files.remote.share`. To show it in a link preview, the app puts the block in its own `chat.unfurl` request. This library does not wrap these methods. Slack shows File blocks in messages that contain remote files.

```crystal
file = UI::Blocks::File.new(external_id: "plan-2026-q4", block_id: "plan.file")
file.to_json
# {"type":"file","external_id":"plan-2026-q4","source":"remote","block_id":"plan.file"}
```

The block always sends `source: "remote"`. The `external_id` must not be empty, and `block_id` is limited to 255 characters. A checked `Message` can contain the block because Slack lists messages as its only surface; `DisplayModal`, `FormModal`, and `Home` reject `Blocks::File` at compile time. This placement does not make `chat.postMessage` or `chat.update` a supported way to share a file. Slack checks that the remote file exists. Received message blocks are not decoded. See the [file block reference](https://docs.slack.dev/reference/block-kit/blocks/file-block/), the [remote file guide](https://docs.slack.dev/messaging/working-with-files/), and the offline [remote-file example](../examples/block_kit_remote_file.cr). The legacy `Slack::UI::Blocks::File` placeholder does not change.

`MessageBlock` now contains `Blocks::File`. An exhaustive `case ... in` or overload set over `MessageBlock` must add a `Blocks::File` branch. Before this change, `Blocks::Input` and `DisplayModalBlock` were sufficient.

## Update a message

Use `CheckedChatUpdate` to replace the blocks and fallback text of an existing message. Pass the channel ID and exact timestamp string returned when posting. For a direct message, use its conversation ID, not a user ID.

```crystal
updated_message = UI.message(fallback_text: "Request 42 approved.") do |builder|
  builder.section(UI.mrkdwn("*Request 42 approved.*"), block_id: "request.approved")
end
channel = response.channel || raise "Missing posted channel"
updated = Slack::Api::CheckedChatUpdate.new(
  token: ENV["SLACK_BOT_TOKEN"], channel: channel, ts: response.ts,
  message: updated_message, as_user: true
).call
puts updated.text
```

The supported request fields are `channel`, `ts`, `text`, `blocks`, and optional `as_user`. The adapter always sends both text and nonempty blocks from an owned checked Message snapshot. It requires explicit fallback text of 1–4000 characters. A Message created with Slack-generated fallback is rejected: text omission on an update does not promise a new accessibility fallback. This is a library policy. Use fresh block IDs for each message version.

This is a content replacement operation, not a partial patch builder. It cannot retain old blocks by omission, clear all blocks, or send a text-only update. Attachments and metadata are omitted and retained by Slack. Parsing and name-linking options are omitted and use Slack's update defaults. Thread, broadcast, unfurl, file, and other method options are outside this adapter. Optional `as_user` preserves omission and explicit false; Slack documents `as_user: true` for updating a bot's own message.

`channel` must not be blank. `ts` must contain digits, a decimal point, and fractional digits; it remains a string without fixed digit counts or rounding. `result`, `call`, and JSON serialization reject invalid local values before dispatch. `result` caches the HTTP response; `call` parses that response as `Slack::Models::Chat::UpdateMessage`, with `channel`, `ts`, `text`, and optional raw `message` JSON. API failures raise `Slack::Errors::Api`. Named `configuration`, `transport`, and `limiter` options reuse the existing dispatch path and are not JSON fields.

The token needs `chat:write`, and only messages owned by the authenticated user or bot can be updated. Ephemeral messages are unsupported. Slack checks ownership, permissions, message state, and rendering. See the [chat.update reference](https://docs.slack.dev/reference/methods/chat.update/) and the offline [message-update example](../examples/block_kit_message_update.cr); stubs do not prove live acceptance.

## Add an overflow menu

Use `BlockElements::Overflow` in a Section accessory or Actions block on any checked surface. It accepts one to five `CompositionObjects::OverflowOption` values, optional `action_id`, and optional `confirm`. Overflow cannot be an Input element.

```crystal
menu = UI::BlockElements::Overflow.new(action_id: "request.more", options: {
  UI::CompositionObjects::OverflowOption.new(text: UI.plain("Archive"), value: "archive"),
  UI::CompositionObjects::OverflowOption.new(text: UI.plain("Details"), value: "details",
    description: UI.plain("Open request"), url: "https://example.com/requests/42"),
})
section = UI::Blocks::Section.new(text: UI.plain("Request 42"), accessory: menu)
```

Option labels and optional descriptions use plain text, up to 75 characters. Values are required, unique within the menu, and limited to 150 characters. URLs allow up to 3000 characters; action IDs allow 255. A nonempty option list is library policy. `OverflowOption` is separate from static-select `Option`, so URL options cannot be passed to static selects. See Slack's [Overflow](https://docs.slack.dev/reference/block-kit/block-elements/overflow-menu-element/) and [Option](https://docs.slack.dev/reference/block-kit/composition-objects/option-object/) references.

On receipt, `OverflowAction#selected_option` exposes the selected value and text through the received `SelectedOption` type. It requires a selection and keeps all received option fields in `raw`; outbound size rules do not apply to received data. Overflow now decodes as `OverflowAction` instead of `UnknownAction`. Move any existing raw Overflow handler to that branch; exhaustive matches on `Interactions::Action` must include the new type. Overflow has no typed state-map entry. URL choices also send an interaction: acknowledge it within three seconds, even when the browser opens the URL.

## Add checkboxes

Use `BlockElements::Checkboxes` with one to ten `CompositionObjects::CheckboxOption` values. Section and Actions support checkboxes on all checked surfaces; Input supports Message, FormModal, and Home. Checkbox labels and descriptions accept plain text or Markdown, up to 75 characters. Values allow 150 characters and must be unique. URL options remain exclusive to Overflow.

```crystal
digest = UI::CompositionObjects::CheckboxOption.new(
  text: UI.mrkdwn("*Daily digest*"), value: "digest",
  description: UI.mrkdwn("_Once a day_"))
control = UI::BlockElements::Checkboxes.new(
  options: {digest}, initial_options: {digest}, action_id: "notifications",
  focus_on_load: false)
```

`initial_options` must exactly match offered options, including text formatting and descriptions. Repeated initial selections and empty option lists are rejected by library policy. Omit `initial_options` or supply an empty collection for no initial selection. Optional `confirm` uses the existing confirmation type. Optional `action_id` allows 255 characters. `focus_on_load` participates in the single-focus rule for views. See Slack's [Checkboxes](https://docs.slack.dev/reference/block-kit/block-elements/checkboxes-element/) and [Option](https://docs.slack.dev/reference/block-kit/composition-objects/option-object/) references.

Checkbox interactions decode as `CheckboxesAction`; state entries decode as `CheckboxesValue`. Read `selected_options` through the action or `state_map.checkboxes_value?(block_id, action_id)`. A cleared selection is a present empty array. Absent and null selections both return nil, with `selected_options_presence` distinguishing them. Received options use `SelectedOption`, preserving unknown fields in `raw` without outbound validation. Set `dispatch_action: true` on an Input block to receive actions when its checkboxes change; submissions also include their state.

Existing raw checkbox handlers must move from `UnknownAction` or `UnknownStateValue` to the new typed branches. Exhaustive matches on `Interactions::Action` and `StateValue` must include the new types. Static-select `Option` and `OverflowOption` contracts are unchanged.

## Add radio buttons

Use `BlockElements::RadioButtons` with one to ten `CompositionObjects::RadioOption` values. Section and Actions support radio buttons on all checked surfaces; Input supports Message, FormModal, and Home. Labels and descriptions accept plain text or Markdown, up to 75 characters. Values allow 150 characters and must be unique. Radio options do not accept URLs.

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

Read `RadioButtonsAction#selected_option` or `state_map.radio_buttons_value?(block_id, action_id)`. A selection is a received `SelectedOption`. Both an absent field and explicit null return nil; `selected_option_presence` distinguishes Absent, Null, and Present. A present option can have an empty string value. Unknown fields remain in `raw`, and outbound limits do not apply to received data. Malformed known fields raise `TypeMismatch`. Set `dispatch_action: true` on an Input block to receive selection changes; submissions also include state.

Radio interactions now decode as `RadioButtonsAction` and `RadioButtonsValue` instead of `UnknownAction` and `UnknownStateValue`. Move existing raw radio handlers to these typed branches. Exhaustive matches on `Interactions::Action`, `StateValue`, and the checked placement unions must include the new types. Existing static, overflow, and checkbox option contracts are unchanged.

## Select an owner and reviewers

Use `BlockElements::UsersSelect` for one user and `MultiUsersSelect` for several users. Both work in Section and Actions on all checked surfaces, and in Input on Message, FormModal, and Home. Slack supplies the users visible to the person using the menu.

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

User interactions now decode as `UsersSelectAction`/`MultiUsersSelectAction` and `UsersSelectValue`/`MultiUsersSelectValue` instead of unknown types. Move raw user-select handlers to these typed branches and extend exhaustive matches on `Interactions::Action`, `StateValue`, and the checked placement unions. The [offline workflow](../examples/block_kit_users_select.cr) assigns an owner, opens a reviewer form, and verifies signed submission state.

## Select notification channels

Use `BlockElements::ChannelsSelect` for one public channel and `MultiChannelsSelect` for several. Slack supplies public channels visible to the person using the menu. Both controls work in Section and Actions on all checked surfaces, and in Input on Message, FormModal, and Home.

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

Only `ChannelsSelect` accepts `response_url_enabled`. Slack documents it for Input blocks in modals. The checked library rejects any supplied value, including `false`, outside that placement; this field-presence restriction is library policy. Omit the field elsewhere. In modal Input, omitted, `false`, and `true` remain distinct. With `true`, Slack can return `response_urls` on submission; inspect the existing raw `ViewSubmission#response_urls`. This adds no response-URL transport or delivery guarantee.

Read `ChannelsSelectAction#selected_channel` (`String?`) and `MultiChannelsSelectAction#selected_channels` (`Array(String)?`), or use `state_map.channels_select_value?` and `state_map.multi_channels_select_value?`. Their `selected_channel_presence` and `selected_channels_presence` distinguish Absent, Null, and Present. A cleared single selection is null; a cleared multi-selection is a present empty array. Missing state entries return nil. Received IDs have no outbound limits; malformed known fields raise path-aware `TypeMismatch`. Raw unknown fields are retained, and selected-array getters return copies. Input can set `dispatch_action: true` for selection changes.

Channel interactions now decode as `ChannelsSelectAction`/`MultiChannelsSelectAction` and `ChannelsSelectValue`/`MultiChannelsSelectValue` instead of unknown types. Move raw channel handlers to these typed branches and extend exhaustive matches on `Interactions::Action`, `StateValue`, and checked placement unions. The [offline workflow](../examples/block_kit_channels_select.cr) selects a notification channel, opens a destination form, and reads signed submission state.

## Select conversations

Use `BlockElements::ConversationsSelect` for one conversation and `MultiConversationsSelect` for several. Slack supplies public and private channels, direct messages, and group direct messages visible to the user. Both controls work in Section and Actions on all checked surfaces, and in Input on Message, FormModal, and Home.

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

Only the single control accepts `response_url_enabled`. It is allowed only in modal Input blocks; rejecting a supplied false outside that placement is library policy, matching ChannelsSelect. Omit it elsewhere. Submission `response_urls` stay available as raw data; this adds no response-URL transport.

Read `ConversationsSelectAction#selected_conversation` (`String?`) and `MultiConversationsSelectAction#selected_conversations` (`Array(String)?`), or use `state_map.conversations_select_value?` and `state_map.multi_conversations_select_value?` with block/action IDs. Presence accessors distinguish Absent, Null, and Present. A cleared single selection is null; a cleared multi-selection is an empty array. Missing entries return nil, malformed known values raise path-aware `TypeMismatch`, and unknown fields stay in raw JSON. Received IDs have no outbound limits; selected-array getters return copies. Input can use `dispatch_action: true` for changes; submissions also carry state.

Migration: these controls now decode as `ConversationsSelectAction`/`MultiConversationsSelectAction` and `ConversationsSelectValue`/`MultiConversationsSelectValue`, instead of unknown types. Move raw handlers to these branches and extend exhaustive matches on `Interactions::Action`, `StateValue`, and checked placement unions. The [offline workflow](../examples/block_kit_conversations_select.cr) posts a filtered conversation menu, reads a signed action, opens a destination form, and reads its signed submission. It does not prove live permissions, rendering, default precedence, remote acceptance, or acknowledgment timing.

## Choose a date and time

Use separate `BlockElements::DatePicker` and `TimePicker` controls in Section or Actions on all checked surfaces, or in Input on Message, FormModal, and Home. These are calendar and clock choices; they do not represent an instant or create a scheduled job.

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

Picker interactions now decode as `DatePickerAction`/`TimePickerAction` and `DatePickerValue`/`TimePickerValue` instead of unknown types. Move raw picker handlers to these typed branches and extend exhaustive matches on `Interactions::Action`, `StateValue`, `Blocks::Section::Accessory`, `Blocks::Actions::Element`, and `Blocks::InputElement`. Legacy placeholder types are unchanged. The [offline scheduling-choice workflow](../examples/block_kit_date_time_pickers.cr) posts a date choice, opens a form, and reads the final date, time, and timezone from a signed submission.

## Choose an instant

Use `BlockElements::DatetimePicker` for one date and time together. Slack sends and returns this value as a Unix timestamp in seconds. Put the picker in Actions or Input on a Message, DisplayModal (Actions only), or FormModal. Slack does not document it for Section accessories or Home, so a Section accessory does not compile and Home validation raises `home.datetimepicker.unsupported_surface`.

```crystal
start = UI::BlockElements::DatetimePicker.new(
  action_id: "start", initial_date_time: Time.utc(2028, 2, 29, 16, 30),
  focus_on_load: true
)
```

The picker supports optional `action_id` (255 characters), `initial_date_time`, `confirm`, and `focus_on_load`. It has no placeholder or timezone field. `initial_date_time` is a `Time`; the library sends whole seconds and drops sub-second precision. Slack documents a ten-digit timestamp, so the value must be from 2001-09-09T01:46:40Z through 2286-11-20T17:46:39Z. Omitted fields and explicit false stay distinct, and one element per view can request focus. See Slack's [datetime picker](https://docs.slack.dev/reference/block-kit/block-elements/datetime-picker-element/) fields and placement metadata.

Read `DatetimePickerAction#selected_date_time`, or `state_map.datetime_picker_value?` with block/action IDs. The selection is `Int64?` Unix seconds as received; use `Time.unix(seconds)` to get a UTC `Time`. `selected_date_time_presence` distinguishes Absent, Null (cleared), and Present. Missing state entries return nil. A non-integer selection or a wrong ID type raises path-aware `TypeMismatch`. Unknown fields remain in `raw`. The library does not apply outbound range rules to received values or create a scheduled job.

Datetime picker interactions now decode as `DatetimePickerAction` and `DatetimePickerValue` instead of unknown types. Extend exhaustive matches on `Interactions::Action`, `StateValue`, `Blocks::Actions::Element`, and `Blocks::InputElement`. The [offline meeting-start workflow](../examples/block_kit_datetime_picker.cr) posts a proposed start, reads a signed choice, opens a form with that start, and reads the saved start from a signed submission.

## Embed a video

A Video block shows an embedded player in a message, modal, or Home tab. It needs `alt_text`, a plain-text `title`, `thumbnail_url`, and `video_url`. Slack prefers `title_url` and `description`.

```crystal
message = Slack::UI::Checked.message(fallback_text: "Release 4.2 walkthrough video") do |builder|
  builder.video(
    alt_text: "Release 4.2 walkthrough",
    title: Slack::UI::Checked.plain("Release 4.2 walkthrough"),
    title_url: "https://videos.example.test/watch/release-4-2",
    description: Slack::UI::Checked.plain("Five minutes on what changed."),
    thumbnail_url: "https://videos.example.test/thumbs/release-4-2.jpg",
    video_url: "https://videos.example.test/embed/release-4-2",
    provider_name: "Example Video")
end
```

Local checks: title and description text fewer than 200 characters, `author_name` fewer than 50 characters, and valid absolute HTTPS URLs for `video_url` and `title_url`. Slack does more checks when it gets the request. The app needs the `links.embed:write` scope, and the `video_url` domain must be in the app's unfurl domains. The page must work in an iframe, must not be on a Slack domain, and must be reachable. A local check does not prove that Slack will play the video.

## Load options from your app

Use `BlockElements::ExternalSelect` for one choice and `MultiExternalSelect` for several. Slack gets the options from your app. Both controls work in Section and Actions on all checked surfaces, and in Input on Message, FormModal, and Home.

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

Pass the signed options-load request to `Slack.process_interaction`. It verifies the signature and timestamp before it parses the payload, and returns a `Slack::Interactions::BlockSuggestion`. Read `action_id`, `block_id`, and `value` (the typed query; it can be an empty string). `user`, `team`, `enterprise`, `api_app_id`, `token`, and `view` are typed as in other interactions; `container`, `channel`, and `message` stay raw JSON. A payload without a string `action_id`, `block_id`, or `value` raises `JSON::SerializableError`.

Answer with a `BlockSuggestionResponse` as HTTP 200 `application/json` within three seconds:

```crystal
case suggestion = Slack.process_interaction(request)
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

Migration: `block_suggestion` payloads now decode as `BlockSuggestion` instead of raising an unknown-discriminator error. External select actions and state now decode as `ExternalSelectAction`/`MultiExternalSelectAction` and `ExternalSelectValue`/`MultiExternalSelectValue` instead of unknown types. Extend exhaustive matches on `Slack::Interaction` subtypes, `Interactions::Action`, `StateValue`, and the checked placement unions. The [offline workflow](../examples/block_kit_external_select.cr) posts an external menu, answers a signed suggestion, reads a signed selection, opens a related-project form, and reads its signed submission. It does not prove live acceptance, rendering, or response timing.

## Show rich text

Use `Blocks::RichText` for formatted display text. Build it from the `Slack::UI::Checked::RichText` types. The block holds containers, and the containers hold inline elements. The types enforce the parent rules that Slack documents:

| Container | Children |
| --- | --- |
| `RichText::Section`, `RichText::Quote` | Text, Link, Emoji, User, Usergroup, Channel, Broadcast, Date, Color, Team, File, Canvas, WorkflowMention |
| `RichText::Preformatted` | Text, Link |
| `RichText::List` | `RichText::Section` only |

```crystal
alias RT = Slack::UI::Checked::RichText
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

Read a received block with `Slack::Interactions::RichText::Block.new(raw, path)`. For example, use a block from `Slack::Events::Message#blocks`. The received types have the same names in `Slack::Interactions::RichText`. They keep `style`, `range`, and numbers as sent, allow empty children, and keep all JSON in `raw`. Slack sets some fields only to describe a received node. Read them on the received types: link `from_llm`, `is_slack_url`, and `truncated`; user and channel `from_llm`; file and canvas `is_skill_invocation`; and workflow mention `channel_id` and `ts`. An unknown node type becomes `RichText::Unknown`. A missing required field, a wrong JSON type, or a known node in the wrong position raises a `TypeMismatch` with the JSON path.

```crystal
reply = Slack::Interactions::RichText::Block.new(event.blocks[0], "event.blocks[0]")
reply.elements.each do |container|
  next unless container.is_a?(Slack::Interactions::RichText::Section)
  container.elements.each do |element|
    puts element.user_id if element.is_a?(Slack::Interactions::RichText::User)
  end
end
```

Migration: received `team`, `file`, `canvas`, and `workflow_mention` nodes now decode as `RichText::Team`, `File`, `Canvas`, and `WorkflowMention` instead of `RichText::Unknown`. Move handlers that match `Unknown#type` to these types, and extend exhaustive matches on `Interactions::RichText::Element` and `UI::Checked::RichText::Element`. Existing constructors are unchanged; the new style flags, `Channel#tab_id`, and `Date#timezone` are optional named arguments.

## Show a table

Use `Blocks::Table` to show rows of cells in a message or on Home. A cell is a `Table::RawText`, a `Table::RawNumber`, or a `Blocks::RichText` for mentions, links, and styles. `RawNumber` sends the number as `value` and shows `text`. Use a `Table::ColumnSetting` to set `align` and `is_wrapped` for a column. Use `nil` to keep the defaults for a column (Slack receives `null`).

```crystal
alias RT = Slack::UI::Checked::RichText
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

Slack permits up to 100 rows, 20 cells in a row, and 20 column settings. Rows can have different numbers of cells. The library also requires at least one row, at least one cell in each row, nonempty raw text, and a finite number. These checks are library policy. `DisplayModal` and `FormModal` reject `Blocks::Table` at compile time, because Slack shows tables only in messages and on Home. Slack limits the characters in all cells of a table, and of all tables in a message, to 10,000. Slack checks this limit. Received message tables are not decoded. See Slack's [table block](https://docs.slack.dev/reference/block-kit/blocks/table-block/) reference and the offline [table example](../examples/block_kit_table.cr).

`MessageBlock` and `HomeBlock` now contain `Blocks::Table`. An exhaustive `case ... in` or overload set over these unions must add a `Blocks::Table` branch.

## Show standard markdown

Use `Blocks::Markdown` to send standard markdown in a message, for example a reply from an LLM. Slack translates the text into its own blocks. One markdown block can become more than one block. Use `MessageBuilder#markdown`, or pass the block to `add`.

```crystal
message = UI.message(fallback_text: "How to rotate the signing secret") do |builder|
  builder.markdown("## Rotate the secret\n\n1. Open **Basic Information**.\n2. Select _Regenerate_.")
end
# {"text":"How to rotate the signing secret",
#  "blocks":[{"type":"markdown","text":"## Rotate the secret\n\n1. Open **Basic Information**.\n2. Select _Regenerate_."}]}
```

Slack limits the text of all markdown blocks in one payload to 12,000 characters. A `Blocks::Markdown` with more text, or a `Message` whose markdown blocks have more text in total, raises `ValidationError` (`markdown.text.too_long` or `message.markdown.too_long`). Send a longer answer as more than one message. Empty text is rejected by library policy. Slack ignores a `block_id` on this block and does not keep it, so `Blocks::Markdown` does not accept one. `Home`, `DisplayModal`, and `FormModal` reject `Blocks::Markdown` at compile time, because Slack shows markdown blocks only in messages. Slack checks how the markdown renders. Received messages contain Slack's translated blocks, not markdown blocks. See Slack's [markdown block](https://docs.slack.dev/reference/block-kit/blocks/markdown-block/) reference and the offline [markdown example](../examples/block_kit_markdown.cr).

`MessageBlock` now contains `Blocks::Markdown`. An exhaustive `case ... in` or overload set over this union must add a `Blocks::Markdown` branch.

## Add feedback and icon buttons

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

Slack does not document the `block_actions` action shape for these elements. `BlockAction#decoded_actions` returns an `UnknownAction` with `type` `"feedback_buttons"` or `"icon_button"`. Read other fields from `raw`:

```crystal
action = interaction.decoded_actions.first
if action.is_a?(Slack::Interactions::UnknownAction) && action.type == "feedback_buttons"
  value = action.raw["value"]?.try(&.as_s?)
end
```

See Slack's [context actions block](https://docs.slack.dev/reference/block-kit/blocks/context-actions-block/), [feedback buttons](https://docs.slack.dev/reference/block-kit/block-elements/feedback-buttons-element/), and [icon button](https://docs.slack.dev/reference/block-kit/block-elements/icon-button-element/) references and the offline [context actions example](../examples/block_kit_context_actions.cr).

`MessageBlock` now contains `Blocks::ContextActions`. An exhaustive `case ... in` or overload set over this union must add a `Blocks::ContextActions` branch.

## Show an alert in a modal

Use `Blocks::Alert` to show a short status in a `DisplayModal` or `FormModal`. The text is a `plain_text` or `mrkdwn` object of up to 200 characters. `level` is a `Blocks::AlertLevel`: `Default`, `Info`, `Warning`, `Error`, or `Success`. If you do not set `level`, the library does not send it, and Slack shows the default level.

```crystal
modal = UI.display_modal(title: UI.plain("Deploy 42")) do |builder|
  builder.alert(UI.mrkdwn("*Migrations* failed"), level: UI::Blocks::AlertLevel::Error, block_id: "check.migrations")
  builder.alert(UI.plain("Build passed"), level: UI::Blocks::AlertLevel::Success)
end
# {"type":"alert","block_id":"check.migrations","text":{"type":"mrkdwn","text":"*Migrations* failed"},"level":"error"}
```

Slack shows alert blocks only in modals. `Message` and `Home` reject `Blocks::Alert` at compile time with the message "Messages and Home tabs reject Alert blocks". Message and Home builders do not have an `alert` helper. Slack's field table lists `text` as a String and `level` as an Array. Slack's example and SDKs send a text object and one string, and the library does the same. An alert sends no interaction payload. See Slack's [alert block](https://docs.slack.dev/reference/block-kit/blocks/alert-block/) reference and the offline [alert example](../examples/block_kit_alert.cr).

`DisplayModalBlock` and `ModalBlock` now contain `Blocks::Alert`. An exhaustive `case ... in` or overload set over these unions must add a `Blocks::Alert` branch. `DisplayModalBlock` is no longer part of `MessageBlock` or `HomeBlock`. To use the same display block in a modal and a message, keep it as its concrete type (for example `Blocks::Divider`), not as a `DisplayModalBlock` value.

## Show a data table

Use `Blocks::DataTable` to show a table that Slack can page and sort, in a message or on Home. Give a `caption`, a `header`, and data `rows`. Slack receives the header as the first row. A header cell is a `Table::RawText` or a `Table::RawNumber`; the compiler rejects a `Blocks::RichText` header cell. A data cell can also be a `Blocks::RichText`.

```crystal
alias RT = Slack::UI::Checked::RichText
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

`DisplayModal` and `FormModal` reject `Blocks::DataTable` at compile time. Slack limits the characters in all cells of a data table, and of all table cells in a message, to 20,000. Slack checks this limit. Slack sorts and pages the table in the client and documents no app payload for these actions. Slack mentions interactive cells, but its reference has no schema for them, so the library does not support them. Received message data tables are not decoded. See Slack's [data table block](https://docs.slack.dev/reference/block-kit/blocks/data-table-block/) reference and the offline [data table example](../examples/block_kit_data_table.cr).

`MessageBlock` and `HomeBlock` now contain `Blocks::DataTable`. An exhaustive `case ... in` or overload set over these unions must add a `Blocks::DataTable` branch.

## Show a chart

Use `Blocks::DataVisualization` to show a pie, bar, area, or line chart in a message or on Home. Slack renders the chart. The block has a `title` and one `DataVisualization::Chart`:

- `PieChart` has `Segment` values. Each segment has a label and a value greater than 0.
- `BarChart`, `AreaChart`, and `LineChart` have `DataSeries` values and one `AxisConfig`. The categories in `AxisConfig` set the x-axis order. Each series must have exactly one `DataPoint` for each category, in any order.

```crystal
alias DV = Slack::UI::Checked::DataVisualization
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

`Message` rejects a third data visualization block. Slack does not state a count for Home, so `Home` does not check one. `DisplayModal` and `FormModal` reject `Blocks::DataVisualization` at compile time. The block has no inbound payload, and received message blocks are not decoded. Offline checks do not prove that Slack renders a chart. See Slack's [data visualization block](https://docs.slack.dev/reference/block-kit/blocks/data-visualization-block/) reference and the offline [chart example](../examples/block_kit_data_visualization.cr).

`MessageBlock` and `HomeBlock` now contain `Blocks::DataVisualization`. An exhaustive `case ... in` or overload set over these unions must add a `Blocks::DataVisualization` branch.

## Enter a number

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

Number input interactions now decode as `NumberInputAction` and `NumberInputValue` instead of unknown types. Extend exhaustive matches on `Interactions::Action`, `StateValue`, and `ModalBlock`. The [offline booking workflow](../examples/block_kit_number_input.cr) opens a number form from a signed button action, reads a dispatched number, rejects an out-of-range submission with `ModalErrors`, and accepts a corrected one.

## Collect uploaded files

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

Read `state_map.file_input_value?` with the block and action IDs. `files` returns `Array(UploadedFile)?`, and `files_presence` distinguishes Absent, Null, and Present (an empty array is Present). Each `UploadedFile` has a required `id` and optional `name`, `title`, `mimetype`, `filetype`, `url_private`, and `url_private_download`. Other file fields stay in `raw`. Wrong JSON types raise path-aware `TypeMismatch`. A `file_input` entry in `actions` stays `UnknownAction`.

```crystal
if value = submission.state_map.file_input_value?("receipts", "files")
  ids = value.files.try(&.map(&.id)) || [] of String
end
```

Migration: `file_input` state entries now decode as `FileInputValue` instead of `UnknownStateValue`, and `Blocks::ModalInputElement` now includes FileInput. Extend exhaustive matches on `StateValue` and `ModalInputElement`. The [offline upload workflow](../examples/block_kit_file_input.cr) opens a receipt form from a signed button action and reads the uploaded file IDs from a signed submission. It does not prove upload completion, file access, or remote acceptance.

## Enter a URL

Use `BlockElements::UrlInput` (wire type `url_text_input`) to collect a link in a form modal. Slack supports this element only in an Input block in a modal. Pass it to `FormModalBuilder#input`, or wrap it in `Blocks::ModalInput`. `Message`, `Home`, and `DisplayModal` do not accept it; the compiler rejects that code.

```crystal
view = UI.form_modal(title: UI.plain("Report a bug"), submit: UI.plain("Send")) do |builder|
  builder.input(label: UI.plain("Page link"), block_id: "bug.link",
    element: UI::BlockElements::UrlInput.new(action_id: "page", placeholder: UI.plain("https://")))
end
```

All fields are optional: `action_id` (255 characters), `initial_value`, `dispatch_action_config`, `focus_on_load`, and a plain-text `placeholder` (150 characters). One element per view can request focus. Slack does not document a format rule for `initial_value`, so the library sends it unchanged.

Read `state_map.url_input_value?(block_id, action_id)` in a submission. With `dispatch_action_config` and `dispatch_action: true` on the block, Slack sends a `UrlInputAction`. Both expose `value : String?` and `value_presence` (Absent, Null, or Present). Slack checks that the entry is a URL. Application rules, such as HTTPS only or an allowed host, stay in the application. Do not fetch a received URL without your own checks.

URL input interactions now decode as `UrlInputAction` and `UrlInputValue` instead of unknown types. Extend exhaustive matches on `Interactions::Action`, `StateValue`, and `Blocks::ModalInputElement`. The [offline bug report workflow](../examples/block_kit_url_input.cr) opens a form from a signed button action, reads a dispatched link, rejects an HTTP link with `ModalErrors`, and accepts an HTTPS link.

## Enter an email address

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

Email input interactions now decode as `EmailInputAction` and `EmailInputValue` instead of unknown types. Extend exhaustive matches on `Interactions::Action` and `StateValue`. The [offline invitation workflow](../examples/block_kit_email_input.cr) opens an email form from a signed button action, reads a dispatched address, rejects an address outside the allowed domain with `ModalErrors`, and accepts a corrected one.

## Enter formatted text

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

Slack requires `action_id` (255 characters) for this element. As library policy, it must not be empty. `initial_value` is a checked `Blocks::RichText`; see [Show rich text](#show-rich-text). Other optional fields are `dispatch_action_config`, `focus_on_load`, a plain-text `placeholder` (150 characters), `min_lines`, and `max_lines`. Each line count must be from 1 to 100. Slack documents no rule between the two counts, so the library does not compare them. Slack also lists the Table block as a parent; the library does not support that placement.

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

Rich text input interactions now decode as `RichTextInputAction` and `RichTextInputValue` instead of unknown types. Extend exhaustive matches on `Interactions::Action`, `StateValue`, `HomeBlock`, and `ModalBlock`. The [offline standup workflow](../examples/block_kit_rich_text_input.cr) publishes a Home composer with a draft, reads text and mentions from a signed dispatched action, and skips a malformed tree.

## Run a workflow from a message

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

Slack does not document a `block_actions` payload for a workflow button click. If Slack sends one, it decodes as `UnknownAction` with raw JSON. The [offline incident workflow](../examples/block_kit_workflow_button.cr) posts workflow buttons with trigger inputs and shows the Home rejection. It does not prove that the trigger is valid or that the workflow runs.

Migration: `Blocks::Section::Accessory` and `Blocks::Actions::Element` now include `WorkflowButton`. Extend exhaustive matches on these unions.

## Build modals and Home

Use `form_modal` for input and `display_modal` for display content. Both have a plain-text title; a form has a required plain-text submit label. A modal can have at most 100 blocks. For a form:

```crystal
alias UI = Slack::UI::Checked
view = UI.form_modal(title: UI.plain("Request reason"), submit: UI.plain("Save")) do |builder|
  builder.input(label: UI.plain("Reason"), block_id: "reason", optional: true,
    element: UI::BlockElements::PlainTextInput.new(action_id: "text", multiline: true))
end

opened = Slack::Api::CheckedViewsOpen.new(
  token: ENV["SLACK_BOT_TOKEN"], trigger_id: trigger_id, view: view
).call
```

The checked open request needs a trigger ID from the interaction and places `external_id` inside the view. A Home view has no title or submit. Its builder accepts the same display blocks and Input. An empty Home is valid; the local maximum is 100 blocks. Publishing needs a user ID. An optional `hash` helps avoid overwriting a newer Home; Slack validates the remote hash and external ID uniqueness.

```crystal
alias UI = Slack::UI::Checked
home = UI.home(callback_id: "projects") do |builder|
  builder.header(text: UI.plain("Your projects"), level: 1)
  builder.context(elements: {UI.mrkdwn("*Project 42*"), UI.plain("Ready for review")})
end

published = Slack::Api::CheckedViewsPublish.new(
  token: ENV["SLACK_BOT_TOKEN"], user_id: user_id, view: home
).call
```

Enable the Home tab and install the app with the permissions required for publishing. The checked publish response exposes the returned view as raw JSON. Slack remains responsible for server access checks and rendering.

## Update a modal

Use `CheckedViewsUpdate` with a checked `FormModal` or `DisplayModal` to replace an existing modal view. The supported request fields are `view`, `view_id`, `external_id`, and optional `hash`. Home updates use `CheckedViewsPublish`; the [modal reference](https://docs.slack.dev/reference/views/modal-views/) lists `views.update`, while the [Home reference](https://docs.slack.dev/reference/views/home-tab-views/) lists `views.publish`.

```crystal
updated_view = UI.form_modal(title: UI.plain("Request reason"), submit: UI.plain("Save")) do |builder|
  builder.section(UI.plain("Add details before saving."))
  builder.input(label: UI.plain("Reason"), block_id: "reason", optional: true,
    element: UI::BlockElements::PlainTextInput.new(action_id: "text", multiline: true))
end
updated = Slack::Api::CheckedViewsUpdate.new(
  token: ENV["SLACK_BOT_TOKEN"], view_id: opened.view["id"].as_s,
  hash: opened.view["hash"].as_s, view: updated_view
).call
```

Supply exactly one nonblank target: `view_id:` from Slack or the developer's `external_id:`. This unambiguous selector rule is library policy, not a claim that Slack rejects both. The external selector allows up to 255 characters. A view's nested `external_id` remains metadata: it never supplies, replaces, or overrides the top-level selector. To target a developer ID, use `external_id: "request-42"` instead of `view_id:`. The nested view may have its own independent external ID.

`hash` is optional and opaque. Omission and an explicit empty string stay distinct; the adapter sends supplied hashes unchanged. Slack checks remote view existence, hash freshness, external ID uniqueness, and access. `not_found` and `hash_conflict` raise `Slack::Errors::Api` through `call`; the adapter does not retry or merge conflicts. See the [method reference](https://docs.slack.dev/reference/methods/views.update/).

Keep each retained input's `block_id` and `action_id` identical to the old view so Slack can preserve entered values. The adapter does not have the old view and cannot validate those matches or migrate state. The [offline open/update workflow](../examples/block_kit_view_update.cr) checks transmitted IDs, not live state preservation. Slack's [modal update guide](https://docs.slack.dev/surfaces/modals/#updating-modal-views) explains input state and hash conflicts.

The constructor owns a view snapshot. JSON serialization, `result`, and `call` validate local values before transport. `result` caches the HTTP response; `call` parses it as `Slack::Models::ViewsUpdate`, exposing `ok?` and raw `view` JSON, including returned IDs, hash, state, and unknown fields. The required String token and named `configuration`, `transport`, and `limiter` options use the existing dispatch path and are not JSON fields. Existing modal placement and submit rules apply. Pushing uses `CheckedViewsPush`; typed error acknowledgments use `ModalErrors`.

## Push the next modal view

Use `CheckedViewsPush` with a checked `FormModal` or `DisplayModal` and a fresh `trigger_id` from an interaction **inside the existing modal**. The supported JSON fields are exactly `trigger_id` and `view`; `external_id`, callback ID, private metadata, and modal flags stay inside `view`. There is no top-level view selector or hash. The alternate `interactivity_pointer` mechanism is unsupported.

```crystal
# interaction is a BlockAction received through Slack.process_interaction.
trigger = interaction.trigger_id || raise "Missing modal trigger"
next_view = UI.form_modal(title: UI.plain("Details"), submit: UI.plain("Save"),
  close: UI.plain("Back"), private_metadata: "42") do |builder|
  builder.input(label: UI.plain("Reason"), block_id: "reason",
    element: UI::BlockElements::PlainTextInput.new(action_id: "text"))
end
pushed = Slack::Api::CheckedViewsPush.new(
  token: ENV["SLACK_BOT_TOKEN"], trigger_id: trigger, view: next_view
).call
```

The constructor owns a modal snapshot and preserves the existing FormModal submit and DisplayModal placement rules. Serialization, `result`, and `call` validate local values before transport. A nonblank trigger is library policy; its format is opaque. `result` caches one HTTP response, and `call` parses it as `Slack::Models::ViewsPush` with `ok?` and raw `view` JSON. A String token is required. Named `configuration`, `transport`, and `limiter` options use the existing API transport and are not JSON fields.

Slack permits three views in a stack, including the root view. Use the new interaction trigger promptly: triggers expire after three seconds and can be exchanged only once. Acknowledge the interaction separately within Slack's response window. The adapter does not track stack depth, verify trigger age or origin, or automatically retry. API failures such as `expired_trigger_id`, `exchanged_trigger_id`, and `push_limit_reached` raise `Slack::Errors::Api` through `call`. See the [method contract](https://docs.slack.dev/reference/methods/views.push/), [modal fields](https://docs.slack.dev/reference/views/modal-views/), and [modal lifecycle guide](https://docs.slack.dev/surfaces/modals/).

The [offline push workflow](../examples/block_kit_view_push.cr) opens a modal, reads a synthetic button interaction from that view, and pushes a form with the fresh trigger. It demonstrates payloads and application flow, not live trigger viability, stack state, permissions, rendering, or handler timing.

## Return modal validation errors

Use `Slack::Interactions::ModalErrors` to acknowledge a `view_submission` with errors. Its `Hash(String, String)` maps Input **block IDs**, not action IDs, to plain-text messages. Slack keeps the view open so the user can correct the input and resubmit. See [Slack's error response guidance](https://docs.slack.dev/surfaces/modals/#display-errors-in-views).

In an HTTP handler with `context : HTTP::Server::Context`, verify the original request before reading state. Route to the expected form by its callback ID, then apply the application's validation:

```crystal
case interaction = Slack.process_interaction(context.request)
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

The route must configure the signing secret and handle other callbacks, interaction types, and verification failures. Return the acknowledgment within Slack's three-second window. An empty HTTP 200 acknowledgment closes the submitted view. The library does not send the acknowledgment or enforce its deadline.

`ModalErrors` copies the supplied map; `errors` returns a copy. Construction rejects an empty map or blank messages with `Slack::UI::Checked::ValidationError`. These are library policies so the response contains useful feedback. `validate` and `validate!` use the existing checked validation conventions. No message length or block-ID format restriction is added. The application owns business rules and must ensure each key identifies an Input block in the submitted view; no original modal is required or checked.

This outbound value needs no token and makes no API request. It is separate from `views.update` and API failure responses. The legacy `Slack::Helpers::Modal::CLOSE` constant is unchanged. The [offline example](../examples/block_kit_modal_errors.cr) verifies signed invalid and corrected submissions and prepares their HTTP responses. Ordinary consumer specs check the complete error body and JSON content type; they do not prove live rendering or handler timing.

## Close the modal stack after submission

Use `Slack::Interactions::ModalClear.new.to_json` as the body of an HTTP 200 JSON response to a successful `view_submission`:

```crystal
response = HTTP::Client::Response.new(200,
  headers: HTTP::Headers{"Content-Type" => "application/json"},
  body: Slack::Interactions::ModalClear.new.to_json)
# Body: {"response_action":"clear"}
```

The application must send the response within three seconds. `clear` closes **all views** in the modal stack. An empty HTTP 200 instead closes only the submitted view and reveals the previous view, if one exists. See [Slack's closing guidance](https://docs.slack.dev/surfaces/modals/#closing-views).

`ModalClear` has no options, needs no token, and makes no API request. The legacy `Slack::Helpers::Modal::CLOSE` named tuple remains unchanged. The [offline clear example](../examples/block_kit_modal_clear.cr) verifies a synthetic signed submission, accepts its input, and prepares the response. Consumer specs independently check its exact body and content type; they do not prove live closure, rendering, or acknowledgment timing.

## Push a view in a submission acknowledgment

Use `Slack::Interactions::ModalPush.new(view: next_view)` after verifying and routing a `view_submission`. It accepts a checked `FormModal` or `DisplayModal` and serializes `response_action: "push"` with the new `view`. Return that JSON as the HTTP 200 acknowledgment within three seconds. See [Slack's push acknowledgment guidance](https://docs.slack.dev/surfaces/modals/#add-a-new-view-via-response_action).

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

`ModalPush` owns a modal snapshot; `view` returns a snapshot. Existing placement, submit, focus, and validation rules apply. `validate` and `validate!` use the checked validation conventions. Callback ID, private metadata, `external_id`, and flags stay inside `view`; Slack checks external-ID uniqueness. `submit_disabled` remains specific to configuration modals.

The application owns HTTP delivery and timing. This value needs no token or trigger and makes no Web API call. Slack owns the stack and permits at most three views; the library does not track stack depth, retry, or enforce the deadline. For a button interaction inside a modal, use the separate `CheckedViewsPush` API adapter described above.

The [offline submission-push example](../examples/block_kit_modal_push.cr) verifies an independently authored signed submission, reads its reason and metadata, and returns the next form as HTTP 200 JSON. Its consumer spec checks the complete acknowledgment body. Offline checks do not prove live stack state, Slack acceptance, rendering, or response timing.

## Update a modal in its submission acknowledgment

Use `Slack::Interactions::ModalUpdate` to replace the currently visible submitted view. Pass an existing checked `FormModal` or `DisplayModal`; the acknowledgment owns a snapshot and `view` returns a snapshot. Existing modal validation, placement, and submit rules apply. `validate` and `validate!` use the checked validation conventions.

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

The JSON contains only `response_action: "update"` and `view`. Modal metadata, including `external_id`, stays inside `view`. This acknowledgment needs no token, target selector, trigger, or hash and performs no API call. `CheckedViewsUpdate` is the separate Web API operation for updating a selected view.

Verify the original signed request with `Slack.process_interaction`, route the expected `ViewSubmission` callback, and return HTTP 200 JSON within three seconds. The application owns response delivery, timing, and handling later submissions. Keep retained input `block_id` and `action_id` values stable. No previous modal is required, so the library cannot check ID matches or preserve remote input state itself. See [Slack's update acknowledgment guidance](https://docs.slack.dev/surfaces/modals/#update-a-view-via-response_action) and [modal fields](https://docs.slack.dev/reference/views/modal-views/).

The [offline example](../examples/block_kit_modal_update.cr) verifies a signed submission, reads its reason, and prepares an updated form with the same reason input IDs and a new owner select. Its consumer spec checks the complete HTTP 200 JSON response; it does not prove live Slack acceptance, rendering, state preservation, or timing.

## Read actions and state

Pass the original signed HTTP request to `Slack.process_interaction`. It checks the signature and timestamp freshness before decoding. For JSON already verified by trusted code, use `Slack::Interaction.from_json`. Timestamp freshness is not duplicate suppression; applications own event deduplication and HTTP acknowledgments.

`BlockAction#decoded_actions` gives typed ButtonAction, StaticSelectAction, MultiStaticSelectAction, ExternalSelectAction, MultiExternalSelectAction, OverflowAction, CheckboxesAction, RadioButtonsAction, UsersSelectAction, MultiUsersSelectAction, ChannelsSelectAction, MultiChannelsSelectAction, ConversationsSelectAction, MultiConversationsSelectAction, DatePickerAction, TimePickerAction, DatetimePickerAction, NumberInputAction, UrlInputAction, EmailInputAction, and RichTextInputAction values with block/action IDs, selections, and raw JSON. A dispatched `plain_text_input` action stays `UnknownAction`. So do `feedback_buttons` and `icon_button` actions, because Slack does not document their action shape; read its text through `state_map`. Unknown action and state families retain raw JSON for application inspection.

```crystal
case interaction = Slack.process_interaction(request)
when Slack::Interactions::ViewSubmission
  reason : String? = interaction.plain_text?("reason", "text")
  if color = interaction.state_map.static_select_value?("preferences", "color")
    selected = color.selected_option.try(&.value)
  end
end
```

`StateMap#plain_text?`, `#static_select_value?`, `#multi_static_select_value?`, `#external_select_value?`, `#multi_external_select_value?`, `#checkboxes_value?`, `#radio_buttons_value?`, `#users_select_value?`, `#multi_users_select_value?`, `#channels_select_value?`, `#multi_channels_select_value?`, `#conversations_select_value?`, `#multi_conversations_select_value?`, `#number_input_value?`, `#file_input_value?`, `#url_input_value?`, `#email_input_value?`, and `#rich_text_input_value?` work on supported BlockAction, View, and ViewSubmission state. A missing block/action key returns nil. For an existing selection entry, the matching `selected_option_presence`, `selected_options_presence`, `selected_user_presence`, `selected_users_presence`, `selected_channel_presence`, `selected_channels_presence`, `selected_conversation_presence`, or `selected_conversations_presence` distinguishes Absent, Null, and Present. A cleared single choice can be null; a cleared multi choice can be a present empty array. `selected_options`, `selected_users`, `selected_channels`, and `selected_conversations` can also be nil if absent or null. Asking for the wrong typed family raises `TypeMismatch`, as do malformed known values; it does not silently return nil. Complete raw JSON remains available for unmodeled fields. This library does not implement a full view lifecycle or response-action framework.

## Validation, limits, and ownership

Constructors check supported local values, and the complete surface checks placement, block IDs, and cross-block rules. `validate` returns `Array(ValidationIssue)`; `validate!` raises `ValidationError`. Each issue has a code, field path, and message. `ValidationError` is an `InvalidUIBlock`.

```crystal
begin
  Slack::UI::Checked::Blocks::Divider.new(block_id: "x" * 256)
rescue error : Slack::UI::Checked::ValidationError
  puts error.issues.first.path # block_id
end
```

Text and field lengths count characters. Common limits: top-level Message 50 blocks, modal/Home 100 blocks, Actions 25 elements, Context 10 elements, a Section 10 fields, block/action IDs 255 characters, Header text 150, and modal title/submit/close labels 24. PlainTextInput supports `min_length`, `max_length`, multiline, and dispatch settings. View surfaces permit only one `focus_on_load: true` element across Section, Actions, and Input. These checks do not prove Slack will accept a remote payload or image.

Checked constructors and builders accept arrays, tuples, and custom enumerables according to the **types actually yielded by `each`**. A broad declared `Enumerable(T?)` is allowed if its `each` yields only supported `T` values. Unsupported yielded values cause a compile error; constructors do no runtime filtering. Inputs are traversed once and copied into owned typed arrays. Getters return snapshots, so changing a caller array, a getter result, or a builder cannot mutate an already built surface or endpoint request.

Use a collection typed for the destination surface. An ordinary `Array(Slack::UI::Checked::MessageBlock)` has an item union that includes Input, File, Table, DataVisualization, Markdown, and ContextActions; it cannot be passed to `DisplayModal` even if its present elements happen to be display blocks. Use `Array(Slack::UI::Checked::DisplayModalBlock)` for that surface. An `Array(Slack::UI::Checked::DisplayModalBlock)` includes Alert, so it cannot be passed to `Message` or `Home`. Legacy conversion helpers remain available in the API for supported mutable Section and Actions values; checked values can be built directly from application data.

## Offline examples

From a repository checkout, run `shards install` to install development dependencies, including WebMock. These commands use synthetic credentials and no Slack network call:

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
crystal run examples/block_kit_remote_file.cr
crystal run examples/block_kit_rich_text.cr
crystal run examples/block_kit_number_input.cr
crystal run examples/block_kit_file_input.cr
crystal run examples/block_kit_url_input.cr
crystal run examples/block_kit_email_input.cr
crystal run examples/block_kit_table.cr
crystal run examples/block_kit_data_table.cr
crystal run examples/block_kit_data_visualization.cr
crystal run examples/block_kit_rich_text_input.cr
crystal run examples/block_kit_markdown.cr
crystal run examples/block_kit_workflow_button.cr
crystal run examples/block_kit_context_actions.cr
crystal run examples/block_kit_alert.cr
```

The message example builds and prints a request. The modal example posts a button, verifies a signed action, opens a form, and reads a signed submission. The Home example publishes through a stub and reads simulated state. The static choice example posts a single choice, reads a signed selection, opens a grouped multi-choice form, and reads its submission. The overflow example posts action and URL choices and acknowledges a signed URL selection. The checkbox example posts initial choices, reads a signed checkbox action, and reads a cleared selection from a signed submission. The radio example posts an initial choice, reads a signed selection, opens an optional override form, and reads an unselected submission. The message-update example replaces a posted approval button with the completed status and new fallback text. The user-select example assigns an owner and submits multiple reviewers. The video example posts a message with a video block and shows a local rejection of an HTTP video link. The external-select example answers a signed options-load request, then reads a signed selection and submission. The remote-file example prints the unfurls value for an application's own `chat.unfurl` request. The rich text example posts formatted release notes with a team mention and a canvas link, and reads mentions, list items, and a workflow mention from a signed message event. The file input example opens a receipt form and reads uploaded file IDs. The number and email input examples open modal-only forms from a signed button, read a dispatched value, and reject then accept a signed submission. The table example posts a revenue table built from application records and shows a local rejection of a row with too many cells. The rich text input example publishes a Home standup composer and reads a signed dispatched action. The markdown example posts an LLM answer as markdown and shows a local rejection of markdown text that is too long for one message. The workflow button example posts incident workflow buttons with trigger inputs and shows a local rejection on Home. The context actions example posts an answer with feedback and delete buttons and reads a signed feedback click as `UnknownAction`. The alert example opens a deploy status modal with one alert for each check and shows a local rejection of alert text that is too long. The data table example posts a paged ticket table and shows a local rejection of a row that is narrower than the header. The data visualization example posts deploy and latency charts built from application records and shows a local rejection of a series with a missing category. Real handlers must acknowledge interactions within Slack's response window.
