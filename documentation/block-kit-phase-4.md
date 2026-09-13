# Block Kit Phase 4 display blocks and Home

Status: implementation and verification complete on 2026-09-12.
Base: `83e7acb23b2a1b93c3acaf5a2a0dfd8bed1114ad` on `robcole/block-kit`.

All new outbound values use `Slack::UI::Checked`. Legacy types keep their names
and behavior. This phase adds Header, Context, image blocks and elements,
SlackFile, Home, HomeBuilder, and CheckedViewsPublish.

## Fields and limits

The official Slack references below were checked on 2026-09-12. Length checks
count characters, not bytes. Absent optional fields are omitted. Explicit false,
zero, and empty metadata are retained.

| Type | Fields and checks | Reference |
| --- | --- | --- |
| Header | Fixed type; required PlainText text (150); optional block_id (255) and Int32 level (1–4). | [Header](https://docs.slack.dev/reference/block-kit/blocks/header-block/) |
| Context | Fixed type; required text/image element collection (at most 10); optional block_id (255). Text objects retain their 3000-character limit. | [Context](https://docs.slack.dev/reference/block-kit/blocks/context-block/), [text](https://docs.slack.dev/reference/block-kit/composition-objects/text-object/) |
| Image element | Fixed type; required String alt_text; exactly one image_url (3000) or SlackFile. The reference gives no alt_text maximum for elements. | [Image element](https://docs.slack.dev/reference/block-kit/block-elements/image-element/) |
| Image block | Fixed type; required alt_text (2000); exactly one image_url (3000) or SlackFile; optional PlainText title (2000) and block_id (255). | [Image block](https://docs.slack.dev/reference/block-kit/blocks/image-block/) |
| SlackFile | Exactly one String id or url. A URL can be the file's url_private or permalink. No locator length limit is published. | [Slack file](https://docs.slack.dev/reference/block-kit/composition-objects/slack-file-object/) |
| Home | Fixed home type; required blocks (at most 100); optional private_metadata (3000), callback_id (255), and external_id. | [Home view](https://docs.slack.dev/reference/views/home-tab-views/) |
| CheckedViewsPublish | Required token, user_id, and checked Home view; optional hash and interactivity_pointer. Token is sent in the Authorization header. | [views.publish](https://docs.slack.dev/reference/methods/views.publish/) |

Header includes the current optional `level` field. Image source constructors are
keyword-only: missing sources, both sources, nil sources, and missing alt text
fail compilation. SlackFile uses the same rule for `id` versus `url`.

Nonempty Context collections, image summaries, image URLs, and file locators are
library policies. The implementation does not parse alt text as markup or inspect
image bytes. Supply a useful plain-text summary. Slack supports PNG, JPG, JPEG,
and GIF image files and checks file access for the posting user. The client does
not fetch images to validate them.

Home has no title, submit, close, or modal lifecycle flags. Empty Home blocks are
accepted, as shown in Slack's [App Home examples](https://docs.slack.dev/surfaces/app-home/).
Home's reference does not publish an external_id length limit; neither do the
[official shared view types](https://github.com/slackapi/node-slack-sdk/blob/main/packages/types/src/views.ts).
This slice does not add one. Slack checks team-wide external ID uniqueness and
whether a request hash still matches the remote view. Hash and interactivity
pointer are opaque strings; no undocumented format or length rule is imposed.

## Placement and availability

| Parent or surface | Accepted checked types |
| --- | --- |
| Section accessory | Button or image element |
| Context elements | PlainText, Mrkdwn, or image element |
| Actions elements | Button |
| Input element | PlainTextInput |
| Message and DisplayModal | Section, Actions, Divider, Header, Context, image block |
| FormModal and Home | Those display blocks plus Input containing PlainTextInput |

The detailed references' Markdown metadata lists message, modal, and Home
availability for [Header](https://docs.slack.dev/reference/block-kit/blocks/header-block.md),
[Context](https://docs.slack.dev/reference/block-kit/blocks/context-block.md),
[image block](https://docs.slack.dev/reference/block-kit/blocks/image-block.md),
and [image element](https://docs.slack.dev/reference/block-kit/block-elements/image-element.md).
No additional feature gate is stated for these display types.

Both [Input metadata](https://docs.slack.dev/reference/block-kit/blocks/input-block.md)
and [PlainTextInput metadata](https://docs.slack.dev/reference/block-kit/block-elements/plain-text-input-element.md)
explicitly list Home. This verifies the existing plain text child on Home without
assuming support for every input child. Home accepts omitted, false, or true
`dispatch_action`; the Input reference specifies false by default. Set it to true
to receive text actions, and use dispatch configuration to choose when they fire.
Home needs no submit label. It checks duplicate supplied block IDs and permits
only one `focus_on_load: true` input. Action IDs may repeat in different blocks.

Slack's metadata also lists message input support. The checked Message union
continues to exclude Input in this slice. This is a library support restriction,
not a claim that Slack prohibits it. Later input work must keep parent and surface
rules explicit. No picker, choice, or new input element is included here.

App Home requires an enabled Home tab and an installed granular-permission app.
The [App Home guide](https://docs.slack.dev/surfaces/app-home/) excludes Deno SDK
apps and workflows. It describes direct HTTP publishing, so using Crystal does
not require a Bolt runtime. The Home view page says Bolt-only, while the guide gives direct HTTP examples.
This implementation follows the guide's HTTP contract.

## Build and publish Home

```crystal
require "slack"

view = Slack::UI::Checked.home(callback_id: "projects", external_id: "projects-U123") do |builder|
  builder.header(text: Slack::UI::Checked.plain("Your projects"), level: 1)
  builder.context(elements: {
    Slack::UI::Checked.mrkdwn("*Project 42*"),
    Slack::UI::Checked.plain("Ready for review"),
  })
  builder.image(
    slack_file: Slack::UI::Checked::CompositionObjects::SlackFile.new(id: "F123"),
    alt_text: "Project 42: three completed tasks and one awaiting review"
  )
end

request = Slack::Api::CheckedViewsPublish.new(
  token: token, user_id: "U123", view: view, hash: previous_hash
)
puts request.to_pretty_json
response = request.call
```

Omit hash for an initial publish. The top-level request contains user_id, view,
and supplied hash/interactivity_pointer. external_id stays inside view. For
public images use `image_url:`. For a Slack URL use `SlackFile.new(url: ...)`.

Every surface builder has `header`, `context`, and both `image` source helpers.
Section helpers accept image accessories. Home also has `section`, `actions`,
`divider`, and `input`. Constructors remain the canonical contract. `add` and
`add_all` accept only the surface's closed union. Typed arrays, mixed tuples,
custom enumerables, and component returns need no casts. Declared enumerable
item types are checked before iteration, even when `each` yields a narrower type.

Constructors copy collections; getters return copies. Reusing a builder or
clearing nested Context or dispatch arrays cannot change a built value. The
endpoint owns a Home snapshot. It validates before serialization and before both
`result` and `call`, including a nonempty user_id. Validation errors retain codes
and nested paths, such as `blocks[3].element.focus_on_load`.

CheckedViewsPublish composes a private Api::Base descriptor because there was no
legacy publish endpoint. The descriptor uses `api_client`, preserving the current
configuration, injected transport, limiter, headers, and response handling. It
receives only the checked serialized body. The public request has no setters or
JSON deserialization. `configuration`, `transport`, and `limiter` keyword settings
are outside the JSON envelope. Offline calls must inject a test transport.

## Migration and inbound limits

Construct the new checked types from application data. The old Header, Context,
and Image placeholders remain outside checked unions. No placeholder conversion
is added. Existing Section and Actions legacy adapters remain available; Section
conversion still supports only its previously implemented legacy Button child.
Legacy modal helpers and the checked message/modal adapters retain their APIs.

Display nodes have no new interactive value. Outbound Home support does not add
an inbound layout decoder. The ViewsPublish response exposes `ok?` and a raw
`JSON::Any` view, including returned IDs, hash, state, blocks, and unknown fields.
Slack API errors use the existing response handler.

Home `block_actions` retain the Phase 3 behavior: ButtonAction exposes IDs and
value, plain text state has typed access with absent/null/empty distinctions,
and unsupported state families remain UnknownStateValue. Dispatched
`plain_text_input` actions remain UnknownAction with complete raw JSON. Read
text from `interaction.state_map`; received view state also has typed access.
Home view envelope fields remain raw. Home fixtures cover absent channel data,
button and text actions, state, and unknown fields. No new submission, routing,
acknowledgment, or view lifecycle framework is introduced.

Run the self-contained offline example:

```sh
crystal run examples/block_kit_home.cr
```

It publishes an accessible Home and reads a simulated text action through
`Interaction.from_json`. The simulated JSON is treated as already verified.
Real HTTP handlers must use `Slack.process_interaction` to verify signatures.
See the [support manifest](block-kit-support.yml) for all partial contracts.

## Verification

Compiler: Crystal 1.21.0 on macOS arm64. The parent baseline had 535 examples.

- `crystal spec`: 610 examples, zero failures, errors, or pending; 1 minute
  13 seconds. This includes all phase compile contracts and offline examples.
- After test-style corrections, the affected checked UI, publish, transport,
  Home interaction, manifest, and Phase 4 compile specs passed again:
  184 examples, zero failures or errors; 22.15 seconds.
- Phase 4 compile checks: 42 examples, including 38 negative fixtures, two
  positive fixtures, and two executions without Slack environment credentials.
- `crystal tool format` on all changed Crystal files, then
  `crystal tool format --check`: pass. `git diff --check`: pass.
- `crystal run lib/ameba/src/cli.cr --no-color`: 383 files, zero failures.
- `crystal docs`: pass, with the existing unavailable-LibXML2 sanitization notice.
- All three `examples/block_kit_{message,modal,home}.cr` examples passed.
  Home published `V123` through WebMock and read `Ready to review` from text state.

New evidence is in
`spec/ui/checked/display_spec.cr`, `spec/ui/checked/home_spec.cr`,
`spec/api/checked_views_publish_spec.cr`, `spec/api/transport_injection_spec.cr`,
`spec/interactions/home_spec.cr`, and `spec/block_kit_phase_4_compile_spec.cr`.
Complete and minimal Home request fixtures, display fixtures, and a Home action
fixture are under `spec/fixtures/block_kit/phase_4_*.json`.

No live Slack request or visual preview is part of this verification. Work stays
in `robcole/block-kit-phase-4`; no parent merge or remote publication is included.
