# Block Kit Phase 5: static choices

Status: first slice implemented and verified on 2026-09-12.
Base: `165650260f5773610f1c2b551728d30c2234e149` on `robcole/block-kit`.
Worktree: `robcole/block-kit-phase-5`. References checked on 2026-09-12.

This slice adds checked options, option groups, single static selects, and multi
static selects. It includes typed selection actions and state. Overflow,
checkbox/radio, user/channel/conversation selects, date/time pickers, external
selects, suggestion payloads, and suggestion responses remain separate slices.

## Fields and limits

All outbound types use `Slack::UI::Checked`. Length checks count characters.

| Type | Supported fields and checks | Official reference |
| --- | --- | --- |
| `CompositionObjects::Option` | Required PlainText `text` (75) and String `value` (150); optional PlainText `description` (75). No discriminator field. | [Option](https://docs.slack.dev/reference/block-kit/composition-objects/option-object/) |
| `CompositionObjects::OptionGroup` | Required PlainText `label` (75) and `options` (at most 100). No discriminator field. | [Option group](https://docs.slack.dev/reference/block-kit/composition-objects/option-group-object/) |
| `BlockElements::StaticSelect` | Fixed `static_select`; exactly one of `options` or `option_groups` (at most 100 each). Optional `action_id` (255), PlainText `placeholder` (150), `initial_option`, `confirm`, and `focus_on_load`. | [Single select](https://docs.slack.dev/reference/block-kit/block-elements/select-menu-element/) |
| `BlockElements::MultiStaticSelect` | Fixed `multi_static_select`; the same source, ID, placeholder, confirmation, and focus fields. Optional `initial_options` and Int32 `max_selected_items` (minimum 1; no documented maximum). | [Multi-select](https://docs.slack.dev/reference/block-kit/block-elements/multi-select-menu-element/) |

Option values must be unique within a menu, including across groups. Initial
options must match the complete offered option, including text, emoji presence,
and description. Multi initial selections must be distinct and cannot exceed
`max_selected_items`. That maximum can exceed the number of available options.
Each group permits 100 options; the implementation does not impose a 100-option
limit across all groups.

Nonempty option/group lists are library policy. Text objects keep their existing
nonempty rule. There is no added minimum for option value strings. Optional
fields are omitted; explicit false, empty option values, and an empty
`initial_options` array are retained. To show no initial selection, prefer to
omit `initial_options`. An omitted single selection uses no `initial_option`.

The option type covers the plain-text menu variant. The `url` field belongs to
overflow only; markdown text and descriptions belong to checkbox/radio variants.
Those variants are not added to this slice. Confirmation uses the existing
checked composition object and its validation.

## Placement and availability

Slack's current [single-select metadata](https://docs.slack.dev/reference/block-kit/block-elements/select-menu-element.md)
and [multi-select metadata](https://docs.slack.dev/reference/block-kit/block-elements/multi-select-menu-element.md)
list Messages, Modals, and Home tabs, with Section, Actions, and Input parents.
The detailed references state no additional feature gate for static sources.
[Input metadata](https://docs.slack.dev/reference/block-kit/blocks/input-block.md)
also lists both menu families and all three surfaces.

| Parent | Checked surfaces for both static variants |
| --- | --- |
| Section accessory | Message, DisplayModal, FormModal, Home |
| Actions element | Message, DisplayModal, FormModal, Home |
| Input element | FormModal, Home |
| Context element or direct surface block | Rejected at compile time |

Message Input remains outside library support. DisplayModal still excludes Input
and FormModal still requires submit. These are explicit library restrictions.
The existing closed placement unions expand by the two concrete select types;
all admitted Input children have the same supported surface set in this slice.
No broad child base type or generic capability system is introduced.

Actions still allows at most 25 elements and checks duplicate supplied action
IDs across Buttons and both select variants. IDs can repeat in different blocks.
Modal and Home validation now finds focus targets in Section, Actions, and Input,
including PlainTextInput. A second target reports its full path, for example
`blocks[1].elements[0].focus_on_load`. Messages have no view focus constraint.
These rules follow the [Actions reference](https://docs.slack.dev/reference/block-kit/blocks/actions-block/)
and the select field references above. Existing Home app requirements still apply;
see the [Phase 4 availability record](block-kit-phase-4.md#placement-and-availability).

## Construction and migration

```crystal
require "slack/ui"

alias UI = Slack::UI::Checked
red = UI::CompositionObjects::Option.new(text: UI.plain("Red"), value: "red")
blue = UI::CompositionObjects::Option.new(text: UI.plain("Blue"), value: "blue")
group = UI::CompositionObjects::OptionGroup.new(
  label: UI.plain("Colors"), options: {red, blue}
)
menu = UI::BlockElements::MultiStaticSelect.new(
  option_groups: {group}, action_id: "colors", initial_options: {red},
  placeholder: UI.plain("Choose colors"), max_selected_items: 2
)
view = UI.form_modal(title: UI.plain("Colors"), submit: UI.plain("Save")) do |builder|
  builder.input(label: UI.plain("Colors"), block_id: "preferences", element: menu)
end
```

Use `StaticSelect` with `initial_option:` for a single choice. Every collection
constructor accepts arrays, tuples, and typed enumerables, checks their declared
item type before iteration, and copies their contents. Getters return copies.
Builders use the same constructors. Retained caller arrays, nested getters, and
builders cannot change a built surface or checked API request.

Legacy `SelectMenu` and `MultiSelectMenu` remain discriminator-only placeholders.
Construct checked values from application data; there is no new legacy menu
conversion. Existing mutable types and conversion helpers retain their behavior.
Checked `Input#element`, `Actions#elements`, and `Section#accessory` now have wider
closed unions. Narrow with `case` or `is_a?` before calling a child-specific method
such as PlainTextInput's `dispatch_action_config`.

The UI-only entrypoint remains credential-free. Sending uses the existing
`CheckedChatPostMessage`, `CheckedViewsOpen`, or `CheckedViewsPublish` adapters.
Their snapshot, serialization, and pre-transport validation boundaries are retained.

## Received selections

Use `Slack::Interaction.from_json` for already verified JSON or
`Slack.process_interaction` for signed HTTP requests. Existing signature and replay
checks remain in place. `BlockAction#decoded_actions` now includes
`StaticSelectAction` and `MultiStaticSelectAction`. Each exposes block/action IDs,
optional string action timestamp, selection access, and complete raw JSON.

`StateMap#static_select_value?` and `#multi_static_select_value?` read the matching
state entry. State maps are available on BlockAction, View, and ViewSubmission.
They also read selections from Section and Actions blocks, not only Input.
The selection shapes follow Slack's official
[action types](https://github.com/slackapi/bolt-js/blob/main/src/types/actions/block-action.ts)
and [view state types](https://github.com/slackapi/bolt-js/blob/main/src/types/view/index.ts).

```crystal
case interaction = Slack::Interaction.from_json(payload)
when Slack::Interactions::ViewSubmission
  if entry = interaction.state_map.multi_static_select_value?("preferences", "colors")
    presence = entry.selected_options_presence
    values = entry.selected_options.try(&.map(&.value))
  end
end
```

| Access | Meaning |
| --- | --- |
| Missing block/action key | Typed accessor returns nil |
| `selected_option_presence` or `selected_options_presence` | Absent, Null, or Present for the selection field |
| `selected_option` | SelectedOption or nil; a cleared single choice is null |
| `selected_options` | Array(SelectedOption) or nil; a cleared multi choice is a present empty array |
| SelectedOption | String `value`, String `text`, String `text_type`, and complete `raw` JSON |

Slack documents cleared single values as null and cleared multi values as `[]` in
its [full-state contract](https://docs.slack.dev/changelog/2020/09/01/full-state-on-view-submisson-and-block-actions/).
The decoder also preserves absent or null multi fields instead of normalizing
them to empty arrays. Empty single objects and malformed selected-option members
raise TypeMismatch at the nested field path. Received text formats and lengths
are not checked against outbound construction rules; extra option fields, emoji,
descriptions, and future text fields remain in raw JSON.

Unknown action/state types still use UnknownAction/UnknownStateValue. Requesting
the wrong typed state family raises TypeMismatch; it does not silently return
nil. Existing raw interaction access is unchanged. There is no automatic inbound
to outbound conversion, response-action framework, or external suggestion support.
The manifest marks inbound coverage partial for the complete wire objects:
selection values and routing IDs are typed, while echoed initial options,
placeholder, confirmation, emoji, and descriptions remain raw.

Run the complete offline example:

```sh
crystal run examples/block_kit_static_select.cr
```

It posts a single select, verifies a synthetic signed action, opens a grouped
multi-select form, verifies a signed submission, and reads the selected values.
Real handlers must acknowledge interactions promptly under Slack's
[interaction contract](https://docs.slack.dev/interactivity/handling-user-interaction/).

## Evidence and verification

| Completion requirement | Retained evidence |
| --- | --- |
| Fields, limits, exact matching, duplicate values, placement, focus paths, nested snapshots | `spec/ui/checked/static_select_spec.cr` |
| Complete single/multi wire forms and message/modal/Home request envelopes | `spec/fixtures/block_kit/phase_5_*.json` |
| Signed and JSON message/modal/Home actions and submissions; absence/null/empty; malformed and unknown data | `spec/interactions/static_select_spec.cr` |
| Both result/call paths on all three checked endpoints after mutation attempts | `spec/api/static_select_snapshot_spec.cr` |
| UI-only loading, arrays/tuples/custom enumerables, normalized unions, components, constructors and builders | `spec/fixtures/compile/pass/phase_5_static_select.cr` |
| Missing/conflicting sources, source-specific fields, markdown, mutation/deserialization, declared-item guards, invalid placement | `spec/block_kit_phase_5_compile_spec.cr` and its 35 negative fixtures |
| Executable signed round trip | `examples/block_kit_static_select.cr` |
| Current supported scope and migration | This record, README, and `block-kit-support.yml` |

Compiler: Crystal 1.21.0 on macOS arm64. The Phase 4 baseline had 610 examples.

- `crystal spec`: **676 examples**, no failures, errors, or pending; 1 minute
  37 seconds. This includes prior phase contracts and all four offline examples.
- After style corrections, checked UI, static-select endpoint and interaction
  specs, Phase 5 compiler contracts, and the manifest passed again:
  **193 examples**, no failures, errors, or pending; 20.03 seconds.
- Phase 5 compiler coverage: **38 examples** (one positive consumer, 35 negative
  contracts, and two credential-free executable checks), included in both runs.
- `crystal tool format` on changed Crystal files and
  `crystal tool format --check`: pass.
- `crystal run lib/ameba/src/cli.cr --no-color`: **437 files**, zero failures.
- `crystal docs`: pass, with the existing unavailable-LibXML2 sanitization notice.
- `crystal run examples/block_kit_static_select.cr`: pass; prints
  `Saved notification colors: red, blue (acknowledged 200)`.
- `git diff --check`: pass, including the staged new files.

All HTTP checks use injected offline transport and synthetic credentials. No live Slack request,
visual preview, parent integration, or remote publication is part of this slice.
Slack still checks app access, remote availability, and aggregate payload limits.
