# Block Kit Phase 3 modals and interactions

Status: implementation and verification complete on 2026-09-12.
Base: `14623fe5621bbcb9a830cbd652a0e3d5ccab1ba6` on `robcole/block-kit`.

Phase 3 adds checked modal construction and trigger-based opening. It also adds
button action decoding and plain text submission access. All checked outbound
values remain under `Slack::UI::Checked`. Existing mutable types keep their names.

## Fields and limits

The following official Slack references were checked on 2026-09-12.

| Contract | Supported fields and validation | Reference |
| --- | --- | --- |
| PlainTextInput | Fixed type; optional action ID (255 characters), initial value, multiline, focus on load, placeholder (plain text, 150), minimum length (Int32, 0–3000), maximum length (Int32, 1–3000), and dispatch configuration. Minimum cannot exceed maximum. | [Plain text input](https://docs.slack.dev/reference/block-kit/block-elements/plain-text-input-element/) |
| DispatchActionConfig | Optional `trigger_actions_on`; when supplied, one or both distinct `DispatchTrigger::OnEnterPressed` and `OnCharacterEntered` values. Empty, duplicate, and unnamed enum values fail validation. | [Dispatch configuration](https://docs.slack.dev/reference/block-kit/composition-objects/dispatch-action-configuration-object/) |
| Input | Fixed type; required plain-text label (2000) and PlainTextInput element; optional block ID (255), plain-text hint (2000), optional, and dispatch_action. | [Input block](https://docs.slack.dev/reference/block-kit/blocks/input-block/) |
| DisplayModal and FormModal | Fixed modal type; title, submit, and close use plain text (24 each); blocks (maximum 100); private_metadata (3000); callback_id (255); external_id (255); clear_on_close, notify_on_close, submit_disabled. | [Modal views](https://docs.slack.dev/reference/views/modal-views/), [external ID limit](https://docs.slack.dev/reference/methods/views.open/) |

Optional fields are omitted. Explicit false, zero, and empty initial text or
metadata remain on the wire. Length checks count characters. The references do
not specify a minimum block count or a separate `initial_value` length constraint;
the library does not add one. It does not require initial text to meet the limits
that Slack applies to user submissions.

A DisplayModal accepts checked Section, Actions, and Divider blocks. Submit and
close are optional. A FormModal also accepts Input and requires submit at compile
time, even if its blocks contain no Input. The builders enforce the same rules.
Input accepts only PlainTextInput in this slice. PlainTextInput is excluded from
Actions and Section accessories. Outbound Home placement remains deferred.

Both modal types validate duplicate supplied block IDs and allow only one input
with `focus_on_load: true`. Action IDs can repeat across different blocks. Omitted
IDs are legal; use explicit IDs when your application must identify a control.
`submit_disabled` is for Slack configuration modals only. The library cannot check
that remote context or enforce team-wide external ID uniqueness.

## Build and open a form

```crystal
require "slack"

view = Slack::UI::Checked.form_modal(
  title: Slack::UI::Checked.plain("Request reason"),
  submit: Slack::UI::Checked.plain("Save"),
  callback_id: "request.reason",
  external_id: "request-42"
) do |builder|
  builder.input(
    label: Slack::UI::Checked.plain("Reason"),
    block_id: "request.reason",
    optional: true,
    element: Slack::UI::Checked::BlockElements::PlainTextInput.new(
      action_id: "reason", max_length: 3000
    )
  )
end

request = Slack::Api::CheckedViewsOpen.new(
  token: token, trigger_id: trigger_id, view: view
)
response = request.call
```

Builders support `add`, `add_all`, `section`, `actions`, and `divider`; the form
builder also has `input`. Constructors and builders accept typed enumerables,
arrays, and tuples. A declared item union containing an unsupported type fails
compilation even if its `each` method yields only supported values.

Constructors copy collections. Getters return copies. Reusing a builder or
changing caller arrays does not change an existing modal or request snapshot.
ValidationError exposes code, path, and message, as in Phase 2.

CheckedViewsOpen uses composition instead of inheriting Api::Base. Both `result`
and `call` validate before transport, including a nonempty trigger ID. The adapter
sends one structured JSON envelope with `trigger_id` and `view`; `external_id`
is inside `view`. Tokens remain in transport headers. Response parsing and Slack
API errors use the existing ViewsOpen model. Its response view remains raw JSON.
Request deserialization and mutable setters are unavailable on the checked path.
The newer `interactivity_pointer` opening path is not implemented.

## Read actions and submitted text

Use `Slack.process_interaction(request)` for a signed HTTP request or
`Slack::Interaction.from_json(json)` for JSON that your application has already
verified. The signed entrypoint retains existing signature and replay checks.

For BlockAction, `decoded_actions` returns `ButtonAction | UnknownAction` values.
ButtonAction exposes `action_id`, `block_id`, optional `value`, and optional string
`action_ts`. Its `raw` field retains other data, such as text and future fields.
A received button needs no outbound label. UnknownAction retains the discriminator
and complete raw value. Dispatched plain text actions remain UnknownAction; use
the interaction's `state_map` to read their text state.
[Block action payloads](https://docs.slack.dev/reference/interaction-payloads/block_actions-payload/)

For ViewSubmission, use `plain_text?(block_id, action_id)` or `state_map`. View
also exposes both methods; BlockAction exposes `state_map` for its top-level state.
Channel, team, view, state, and response URLs remain optional where the existing
public parser permits them. A missing view produces an absent state map.
[View interaction fields](https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload/)

```crystal
case interaction = Slack::Interaction.from_json(payload)
when Slack::Interactions::ViewSubmission
  reason = interaction.plain_text?("request.reason", "reason") # String?
  entry = interaction.state_map.plain_text_value?("request.reason", "reason")
  presence = entry.try(&.value_presence)
end
```

| Access | Meaning |
| --- | --- |
| `state_map.presence` | Absent, Null, or Present for state. An empty object is Present. |
| `state_map.values_presence` | The same distinction for state.values. |
| `state_map[block_id, action_id]?` | Nil for a missing key; otherwise PlainTextValue or UnknownStateValue with raw JSON. |
| `plain_text_value?` | Nil for a missing entry; otherwise a typed entry with value and value_presence. |
| `plain_text?` | String or nil. Empty string stays empty; missing or null text yields nil. |

Use the entry and its presence when the short String? accessor is insufficient.
Unknown state families retain raw JSON, including nulls and empty selection
arrays. Asking for plain text from an unknown state type raises TypeMismatch.
Malformed known values also raise TypeMismatch with the block/action path,
expected type, and actual type. Raw parsing remains available before typed access.
Slack documents cleared text as null and cleared multi-selections as empty arrays.
[Full-state and empty-state contract](https://docs.slack.dev/changelog/2020/09/01/full-state-on-view-submisson-and-block-actions/)

## Migration and support limits

Keep existing `Slack::UI::Modal`, `Api::ViewsOpen`, and component helpers while
migrating. Construct new checked Input and modal values from application data.
The checked request rejects a legacy Modal; it does not silently treat mutable
legacy objects as snapshots. Phase 2's Section and Actions conversion helpers
remain available for content you reuse in a checked modal. There is no new legacy
Input or whole-modal conversion helper in this slice.

Existing raw `BlockAction#actions`, `BlockAction#state`, and View JSON access remain
available. Adopt typed accessors one handler at a time. These inbound DTOs remain
separate from immutable outbound values.

Typed select values, suggestions, modal error/update/push/clear response actions,
view lifecycle adapters, and a routing framework are deferred. This phase does
not claim complete Block Kit or complete modal interaction support. See the
[support manifest](block-kit-support.yml) for each partial contract.

Run the complete offline round trip:

```sh
crystal run examples/block_kit_modal.cr
```

It posts a checked message with WebMock, verifies a synthetic signed button
interaction, opens a checked form, verifies a synthetic signed submission, and
reads the submitted reason. Real handlers must acknowledge interactions promptly;
Slack requires a submission response within three seconds, and trigger IDs expire
within three seconds. An empty HTTP 200 acknowledges a successful submission.
[Modal interaction guide](https://docs.slack.dev/surfaces/modals/)

## Validation record

Compiler: Crystal 1.21.0 on macOS arm64. The integrated Phase 2 baseline had
428 examples; its earlier 341-example record remains historical.

- `crystal spec`: 508 examples, zero failures, errors, or pending; 39.57 seconds.
  This includes 25 Phase 3 compiler/entrypoint checks and both offline examples.
- `crystal tool format` on changed Crystal files, then
  `crystal tool format --check`: pass.
- `crystal run lib/ameba/src/cli.cr --no-color`: 305 files, zero failures.
- `crystal docs`: pass, with the existing unavailable-LibXML2 sanitization notice.
- `crystal run examples/block_kit_message.cr`: pass.
- `crystal run examples/block_kit_modal.cr`: pass; the signed round trip reads
  `Need a test environment.` and acknowledges the submission with HTTP 200.

Wire fixtures are in `spec/fixtures/block_kit/phase_3_*.json`. Runtime evidence is
in `spec/ui/checked/input_spec.cr`, `spec/ui/checked/modal_spec.cr`,
`spec/api/checked_views_open_spec.cr`, and `spec/interactions/block_kit_spec.cr`.
Compile contracts are in `spec/block_kit_phase_3_compile_spec.cr`. Phase 0's
synthetic modal guards now live under `Proof::DeclaredTypes`, so loading its
historical proofs cannot replace production modal guards in the complete suite.

All HTTP tests use WebMock and synthetic credentials. No live Slack request or
visual preview was performed. The work stays in `robcole/block-kit-phase-3`;
no parent merge or remote publication is included.
