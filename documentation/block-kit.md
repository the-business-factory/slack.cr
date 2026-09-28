# Checked Block Kit

Use `require "slack"` and `Slack::UI::Checked` to construct validated, immutable outbound values. Construction and JSON inspection need no Slack credentials. Sending needs a token with the relevant Slack API scope, and signed interaction handling needs the app signing secret. The [README](../README.md) has a complete message example and commands for offline workflows.

## Supported surfaces and placement

| Checked surface | Direct blocks | Input children | Send with |
| --- | --- | --- | --- |
| `Message` | Section, Actions, Divider, Header, Context, Image, Input | PlainTextInput, StaticSelect, MultiStaticSelect, Checkboxes, RadioButtons | `Slack::Api::CheckedChatPostMessage`, `Slack::Api::CheckedChatUpdate` |
| `DisplayModal` | Section, Actions, Divider, Header, Context, Image | None, even if a submit label is supplied | `Slack::Api::CheckedViewsOpen` |
| `FormModal` | Section, Actions, Divider, Header, Context, Image, Input | PlainTextInput, StaticSelect, MultiStaticSelect, Checkboxes, RadioButtons | `Slack::Api::CheckedViewsOpen` |
| `Home` | Section, Actions, Divider, Header, Context, Image, Input | PlainTextInput, StaticSelect, MultiStaticSelect, Checkboxes, RadioButtons | `Slack::Api::CheckedViewsPublish` |

`FormModal` always needs a plain-text `submit` label, including forms without Input. `DisplayModal` cannot contain Input. Message and Home need no submit label. A Message can contain Input even though older phase notes excluded it. [Slack's Input reference](https://docs.slack.dev/reference/block-kit/blocks/input-block.md) lists Messages, Modals, and Home.

| Parent | Supported children |
| --- | --- |
| Section accessory | Button, Image element, StaticSelect, MultiStaticSelect, Overflow, Checkboxes, RadioButtons |
| Actions elements | Button, StaticSelect, MultiStaticSelect, Overflow, Checkboxes, RadioButtons |
| Context elements | PlainText, Mrkdwn, Image element |
| Input element | PlainTextInput, StaticSelect, MultiStaticSelect, Checkboxes, RadioButtons |

Checked Header, Context, and Image blocks are display content on all four surfaces. An Image block or element needs alt text and exactly one public `image_url` or `SlackFile` source. `SlackFile` takes an ID or URL. Remote image availability and file access are checked by Slack. Section supports text, fields, and the listed accessory; Actions checks duplicate supplied action IDs within that block.

Static choices use plain-text `Option` values, optional `OptionGroup` values, and exactly one `options:` or `option_groups:` source. `StaticSelect` has one `initial_option`; `MultiStaticSelect` has `initial_options` and optional `max_selected_items`. Choice values must be unique within a menu, and initial selections must match offered options. Each group can contain up to 100 options. The supported menu is a **static** source; external or dynamic sources are outside this checked API.

Date/time pickers and user, channel, or conversation select families are not checked implementations. Placeholder or mutable types elsewhere in the library do not extend the checked placement matrix. The checked endpoints cover only their documented request fields; they are not complete wrappers for every Slack method field or view lifecycle action.

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

## Read actions and state

Pass the original signed HTTP request to `Slack.process_interaction`. It checks the signature and timestamp freshness before decoding. For JSON already verified by trusted code, use `Slack::Interaction.from_json`. Timestamp freshness is not duplicate suppression; applications own event deduplication and HTTP acknowledgments.

`BlockAction#decoded_actions` gives typed ButtonAction, StaticSelectAction, MultiStaticSelectAction, OverflowAction, CheckboxesAction, and RadioButtonsAction values with block/action IDs, selections, and raw JSON. A dispatched `plain_text_input` action stays `UnknownAction`; read its text through `state_map`. Unknown action and state families retain raw JSON for application inspection.

```crystal
case interaction = Slack.process_interaction(request)
when Slack::Interactions::ViewSubmission
  reason : String? = interaction.plain_text?("reason", "text")
  if color = interaction.state_map.static_select_value?("preferences", "color")
    selected = color.selected_option.try(&.value)
  end
end
```

`StateMap#plain_text?`, `#static_select_value?`, `#multi_static_select_value?`, `#checkboxes_value?`, and `#radio_buttons_value?` work on supported BlockAction, View, and ViewSubmission state. A missing block/action key returns nil. For an existing selection entry, `selected_option_presence` or `selected_options_presence` distinguishes Absent, Null, and Present. A cleared single choice can be null; a cleared multi choice can be a present empty array. `selected_options` can also be nil if absent or null. Asking for the wrong typed family raises `TypeMismatch`, as do malformed known values; it does not silently return nil. Complete raw JSON remains available for unmodeled fields. This library does not implement a full view lifecycle, response-action framework, or external suggestion responses.

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

Use a collection typed for the destination surface. An ordinary `Array(Slack::UI::Checked::MessageBlock)` has an item union that includes Input; it cannot be passed to `DisplayModal` even if its present elements happen to be display blocks. Use `Array(Slack::UI::Checked::DisplayModalBlock)` for that surface. Legacy conversion helpers remain available in the API for supported mutable Section and Actions values; checked values can be built directly from application data.

## Offline examples

From a repository checkout, run `shards install` to install development dependencies, including WebMock. All eight commands use synthetic credentials and no Slack network call:

```sh
crystal run examples/block_kit_message.cr
crystal run examples/block_kit_modal.cr
crystal run examples/block_kit_home.cr
crystal run examples/block_kit_static_select.cr
crystal run examples/block_kit_overflow.cr
crystal run examples/block_kit_checkboxes.cr
crystal run examples/block_kit_radio_buttons.cr
crystal run examples/block_kit_message_update.cr
```

The message example builds and prints a request. The modal example posts a button, verifies a signed action, opens a form, and reads a signed submission. The Home example publishes through a stub and reads simulated state. The static choice example posts a single choice, reads a signed selection, opens a grouped multi-choice form, and reads its submission. The overflow example posts action and URL choices and acknowledges a signed URL selection. The checkbox example posts initial choices, reads a signed checkbox action, and reads a cleared selection from a signed submission. The radio example posts an initial choice, reads a signed selection, opens an optional override form, and reads an unselected submission. The message-update example replaces a posted approval button with the completed status and new fallback text. Real handlers must acknowledge interactions within Slack's response window.
