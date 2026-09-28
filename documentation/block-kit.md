# Checked Block Kit

Use `require "slack"` and `Slack::UI::Checked` to construct validated, immutable outbound values. Construction and JSON inspection need no Slack credentials. Sending needs a token with the relevant Slack API scope, and signed interaction handling needs the app signing secret. The [README](../README.md) has a complete message example and commands for offline workflows.

## Supported surfaces and placement

| Checked surface | Direct blocks | Input children | Send with |
| --- | --- | --- | --- |
| `Message` | Section, Actions, Divider, Header, Context, Image, Input | PlainTextInput, StaticSelect, MultiStaticSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect | `Slack::Api::CheckedChatPostMessage`, `Slack::Api::CheckedChatUpdate` |
| `DisplayModal` | Section, Actions, Divider, Header, Context, Image | None, even if a submit label is supplied | `Slack::Api::CheckedViewsOpen`, `Slack::Api::CheckedViewsUpdate`, `Slack::Api::CheckedViewsPush` |
| `FormModal` | Section, Actions, Divider, Header, Context, Image, Input | PlainTextInput, StaticSelect, MultiStaticSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect | `Slack::Api::CheckedViewsOpen`, `Slack::Api::CheckedViewsUpdate`, `Slack::Api::CheckedViewsPush` |
| `Home` | Section, Actions, Divider, Header, Context, Image, Input | PlainTextInput, StaticSelect, MultiStaticSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect | `Slack::Api::CheckedViewsPublish` |

`FormModal` always needs a plain-text `submit` label, including forms without Input. `DisplayModal` cannot contain Input. Message and Home need no submit label. A Message can contain Input even though older phase notes excluded it. [Slack's Input reference](https://docs.slack.dev/reference/block-kit/blocks/input-block.md) lists Messages, Modals, and Home.

| Parent | Supported children |
| --- | --- |
| Section accessory | Button, Image element, StaticSelect, MultiStaticSelect, Overflow, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect |
| Actions elements | Button, StaticSelect, MultiStaticSelect, Overflow, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect |
| Context elements | PlainText, Mrkdwn, Image element |
| Input element | PlainTextInput, StaticSelect, MultiStaticSelect, Checkboxes, RadioButtons, UsersSelect, MultiUsersSelect, ChannelsSelect, MultiChannelsSelect |

Checked Header, Context, and Image blocks are display content on all four surfaces. An Image block or element needs alt text and exactly one public `image_url` or `SlackFile` source. `SlackFile` takes an ID or URL. Remote image availability and file access are checked by Slack. Section supports text, fields, and the listed accessory; Actions checks duplicate supplied action IDs within that block.

Static choices use plain-text `Option` values, optional `OptionGroup` values, and exactly one `options:` or `option_groups:` source. `StaticSelect` has one `initial_option`; `MultiStaticSelect` has `initial_options` and optional `max_selected_items`. Choice values must be unique within a menu, and initial selections must match offered options. Each group can contain up to 100 options. These two types use a **static** source. User and channel selects use Slack-provided lists; external option sources remain unsupported.

Date/time pickers and conversation select families are not checked implementations. Placeholder or mutable types elsewhere in the library do not extend the checked placement matrix. The checked endpoints cover only their documented request fields; they are not complete wrappers for every Slack method field or view lifecycle action.

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

This outbound value needs no token and makes no API request. It is separate from `views.update` and API failure responses. Typed `update`, `push`, and `clear` response actions remain unsupported; the legacy `Slack::Helpers::Modal::CLOSE` constant is unchanged. The [offline example](../examples/block_kit_modal_errors.cr) verifies signed invalid and corrected submissions and prepares their HTTP responses. Ordinary consumer specs check the complete error body and JSON content type; they do not prove live rendering or handler timing.

## Read actions and state

Pass the original signed HTTP request to `Slack.process_interaction`. It checks the signature and timestamp freshness before decoding. For JSON already verified by trusted code, use `Slack::Interaction.from_json`. Timestamp freshness is not duplicate suppression; applications own event deduplication and HTTP acknowledgments.

`BlockAction#decoded_actions` gives typed ButtonAction, StaticSelectAction, MultiStaticSelectAction, OverflowAction, CheckboxesAction, RadioButtonsAction, UsersSelectAction, MultiUsersSelectAction, ChannelsSelectAction, and MultiChannelsSelectAction values with block/action IDs, selections, and raw JSON. A dispatched `plain_text_input` action stays `UnknownAction`; read its text through `state_map`. Unknown action and state families retain raw JSON for application inspection.

```crystal
case interaction = Slack.process_interaction(request)
when Slack::Interactions::ViewSubmission
  reason : String? = interaction.plain_text?("reason", "text")
  if color = interaction.state_map.static_select_value?("preferences", "color")
    selected = color.selected_option.try(&.value)
  end
end
```

`StateMap#plain_text?`, `#static_select_value?`, `#multi_static_select_value?`, `#checkboxes_value?`, `#radio_buttons_value?`, `#users_select_value?`, `#multi_users_select_value?`, `#channels_select_value?`, and `#multi_channels_select_value?` work on supported BlockAction, View, and ViewSubmission state. A missing block/action key returns nil. For an existing selection entry, the matching `selected_option_presence`, `selected_options_presence`, `selected_user_presence`, `selected_users_presence`, `selected_channel_presence`, or `selected_channels_presence` distinguishes Absent, Null, and Present. A cleared single choice can be null; a cleared multi choice can be a present empty array. `selected_options`, `selected_users`, and `selected_channels` can also be nil if absent or null. Asking for the wrong typed family raises `TypeMismatch`, as do malformed known values; it does not silently return nil. Complete raw JSON remains available for unmodeled fields. This library does not implement a full view lifecycle, response-action framework, or external suggestion responses.

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

From a repository checkout, run `shards install` to install development dependencies, including WebMock. All thirteen commands use synthetic credentials and no Slack network call:

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
crystal run examples/block_kit_channels_select.cr
```

The message example builds and prints a request. The modal example posts a button, verifies a signed action, opens a form, and reads a signed submission. The Home example publishes through a stub and reads simulated state. The static choice example posts a single choice, reads a signed selection, opens a grouped multi-choice form, and reads its submission. The overflow example posts action and URL choices and acknowledges a signed URL selection. The checkbox example posts initial choices, reads a signed checkbox action, and reads a cleared selection from a signed submission. The radio example posts an initial choice, reads a signed selection, opens an optional override form, and reads an unselected submission. The message-update example replaces a posted approval button with the completed status and new fallback text. The user-select example assigns an owner and submits multiple reviewers. Real handlers must acknowledge interactions within Slack's response window.
