# Block Kit Phase 2 checked messages

Status: implementation complete on 2026-09-12.

Base integration commit: `7f1b24376f0ebd5d031feabd07b028657d1e720d`.
Compiler: Crystal 1.21.0 on `aarch64-apple-darwin25.6.0`.

Phase 2 publishes immutable outbound values under `Slack::UI::Checked`. The
existing mutable Phase 1 types keep their names and valid behavior.

## Supported message slice

The checked slice includes these values:

- `CompositionObjects::PlainText` and `CompositionObjects::Mrkdwn` have fixed
  wire types. They expose only `emoji` or `verbatim`, as applicable.
- `CompositionObjects::Confirmation` has checked title, body, confirm, deny, and
  style values. The body accepts plain text or `mrkdwn`. Slack's field table says
  plain text, but Slack's current official JSON and SDK examples use `mrkdwn`.
- `BlockElements::Button` supports `text`, `action_id`, `url`, `value`, `style`,
  `confirm`, `accessibility_label`, and `agent_prompt`.
- `Blocks::Section` supports text-only, fields-only, and combined content. It
  supports `block_id`, `expand`, and a checked Button accessory.
- `Blocks::Actions` supports one to 25 checked Buttons. It checks supplied action
  IDs for duplicates in the block.
- `Blocks::Divider` supports its fixed type and optional `block_id`.
- `Message` and `MessageBuilder` accept checked Section, Actions, and Divider
  blocks. A message accepts one to 50 blocks and checks supplied block IDs for
  duplicates.

The field and size rules were checked against the current official references:
[text](https://docs.slack.dev/reference/block-kit/composition-objects/text-object/),
[confirmation](https://docs.slack.dev/reference/block-kit/composition-objects/confirmation-dialog-object/),
[Button](https://docs.slack.dev/reference/block-kit/block-elements/button-element/),
[Section](https://docs.slack.dev/reference/block-kit/blocks/section-block/),
[Actions](https://docs.slack.dev/reference/block-kit/blocks/actions-block/), and
[Divider](https://docs.slack.dev/reference/block-kit/blocks/divider-block/).

Section and Actions placement remains partial because their checked child unions
include only Button. Later phases will add other element families after their
fields, limits, and placements are complete. Button interaction decoding was deferred in Phase 2 and is now available in
[Phase 3](block-kit-phase-3.md).

## Accessibility choices

Slack screen readers use the top-level message `text` before interior blocks.
Choose one of the two explicit constructors:

```crystal
message = Slack::UI::Checked.message(fallback_text: "Request 42 needs approval.") do |builder|
  builder.section(Slack::UI::Checked.mrkdwn("*Request 42*"))
end

derived = Slack::UI::Checked.message_with_slack_generated_fallback do |builder|
  builder.section(Slack::UI::Checked.plain("Slack derives the fallback."))
end
```

The first form sends the supplied fallback. The second form omits top-level
`text` so Slack can derive accessible content from supported blocks. The library
does not make a partial summary.

## Validation issues

Constructors validate local values. Message construction validates the complete
layout. `validate` returns `Array(ValidationIssue)`, and `validate!` raises
`ValidationError`. `ValidationError` is an `InvalidUIBlock`, so existing rescue
logic still works. Each issue has a stable code, field path, and short message.

```crystal
begin
  Slack::UI::Checked::Blocks::Divider.new(block_id: "x" * 256)
rescue error : Slack::UI::Checked::ValidationError
  issue = error.issues.first
  puts issue.code # divider.block_id.too_long
  puts issue.path # block_id
end
```

Checked collections copy caller data and return copies. A retained array,
builder, getter result, or legacy object cannot change a completed snapshot.

## Sending a checked message

`Slack::Api::CheckedChatPostMessage` uses composition. It does not inherit the
mutable setters or JSON deserializer from `Api::Base`. It copies the Message,
validates in both `result` and `call`, builds one JSON envelope, and uses the
existing API client for headers, rate limiting, transport, and response parsing.

```crystal
request = Slack::Api::CheckedChatPostMessage.new(
  token: "xoxb-synthetic",
  channel: "C123",
  message: message,
  thread_ts: "1710000000.000001",
  reply_broadcast: false,
  unfurl_links: false,
  unfurl_media: false
)
```

The checked adapter supports `channel`, Message `text` and `blocks`, `thread_ts`,
`reply_broadcast`, `unfurl_links`, and `unfurl_media`. It is explicitly partial
for the complete `chat.postMessage` method. Use the existing
`Slack::Api::ChatPostMessage` when you need `attachments`, `parse`, `link_names`,
`mrkdwn`, `username`, `icon_emoji`, or `icon_url`. These legacy request fields are
outside the checked guarantee. Neither request supports `metadata`,
`markdown_text`, or draft fields. See the current
[`chat.postMessage` reference](https://docs.slack.dev/reference/methods/chat.postMessage/).

## Migration

New code can construct checked values directly:

```crystal
button = Slack::UI::Checked::BlockElements::Button.new(
  text: Slack::UI::Checked.plain("Approve"),
  action_id: "request.approve"
)
section = Slack::UI::Checked::Blocks::Section.new(
  text: Slack::UI::Checked.mrkdwn("*Request 42*"),
  accessory: button
)
```

Existing helpers keep their concrete legacy return types. Convert their results
when gradual migration is useful:

```crystal
legacy_section = Slack::UI::Components::TextSection.render("*Request 42*", markdown: true)
checked_section = Slack::UI::Checked::LegacyAdapter.section(legacy_section)

legacy_actions = Slack::UI::Components::ButtonActions.render(action_id: "request")
checked_actions = Slack::UI::Checked::LegacyAdapter.actions(legacy_actions)
```

Conversion checks mutable discriminators and makes a recursive copy. New custom
components need no base class. They can return a checked block or implement
`render_into(builder : Slack::UI::Checked::MessageBuilder) : Nil`. Run the
complete offline example with:

```sh
crystal run examples/block_kit_message.cr
```

## Validation record

The final validation used WebMock and synthetic credentials. No request was sent
to Slack.

- `crystal spec`: 341 examples, zero failures, zero errors, and zero pending.
- `crystal tool format --check`: pass.
- `crystal run lib/ameba/src/cli.cr --no-color`: 256 files inspected, zero
  failures.
- `crystal docs`: pass; this compiler reports that LibXML2 sanitization is not
  available.
- `crystal spec spec/block_kit_support_manifest_spec.cr`: one example, zero
  failures.
- `crystal run examples/block_kit_message.cr`: pass.
