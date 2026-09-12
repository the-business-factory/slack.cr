# Block Kit architecture and rollout plan

Status: revised after first-pass review; approved for phase 0.
Implementation has not started. The public API names below remain provisional
until phase 0 proves the migration boundary.
Assessed on 2026-09-12 against branch `next`, commit
`3d69c462877d439ef66dda92def82295abd457f2`, using Crystal 1.21.0.

## 1. Objective and boundaries

Make Slack layouts simple to compose, reuse, inspect, and send. Use Crystal types
to reject invalid structure wherever practical. Validate dynamic values locally
before HTTP. Add Block Kit support in small releases without changing these
principles for each new element.

The design covers composition objects, elements, blocks, surfaces, reusable app
components, serialization, and interaction data. It does not require all of them
to ship together. A type is supported only when its documented fields, placement
rules, validation, and tests are complete for the declared support scope.

Slack separates composition objects, elements, and blocks, and places blocks in
messages, modals, and Home tabs. Message layouts allow up to 50 blocks; modal and
Home layouts allow up to 100. Use these concepts directly in the library.
[Slack Block Kit overview](https://docs.slack.dev/block-kit/)

Do not make an OAuth rewrite, a new HTTP framework, a UI renderer, a schema
generator, or a complete interaction router prerequisites. Keep the existing API
client and offline test tools. Plan endpoint changes only where they connect the
new payloads to Slack.

## 2. Assessment of the current structure

The directory structure is a useful starting point. It already separates
`ui/blocks`, `ui/block_elements`, `ui/composition_objects`, `ui/components`, API
endpoints, and interaction payloads. Preserve these names where possible.

| Area | Current evidence | Consequence and proposed action |
| --- | --- | --- |
| Block catalog | `Actions`, `Input`, and `Section` have partial implementations. `Context`, `Divider`, `File`, `Header`, and block `Image` are empty structs. | Keep placeholders out of new supported unions. Implement one complete slice at a time. |
| Element catalog | `Button` and `PlainTextInput` have fields. Checkbox, date picker, image, multi-select, overflow, radio group, select, and time picker only have discriminators. | A filename is not evidence of usable support. Track fields and placement explicitly. |
| Text composition | `ui/dynamic_text_composition.cr` generates a separate nested text type for each field, with mutable `type : String`, `emoji`, and `verbatim`. | Callers can put `mrkdwn` into fields that require plain text. Replace this mechanism with shared distinct text types. |
| Constructors | `mixins/initializer_macros.cr` generates public setters and initializer hooks; it is also used outside UI. | Validation can be invalidated after construction. Replace its use in new UI models without changing the global macro. |
| Parent constraints | Actions accept only button arrays, Input accepts only plain text input, and Section accepts the broad abstract `BlockElement`. | Some valid combinations are unavailable and some invalid combinations compile. Introduce explicit child-slot unions. |
| Serialization | Section exposes `block_id` but its serializer drops it. Section also permits a mutable discriminator. Other types mix generated and custom serialization. | Define one wire contract per type and test omitted fields, fixed discriminators, and all exposed fields. |
| Limits | Actions enforce five elements; modal title/submit/close allow 100/50/50 characters; plain text input uses `Int8` for `min_length`. | Correct the existing limits and numeric types before expanding support. |
| Missing validation | Actions permit nil elements; Section permits empty fields with no text. Several identifier lengths and cross-field rules are unchecked. | Require structure in constructors and validate collection contents and values. |
| Surface model | Only `UI::Modal` exists. `TypeAliases::ModalBlock` includes incomplete structs. Modal always requires submit and close. | Add distinct message, Home, and modal payload contracts, with correct required fields. |
| API boundary | `ChatPostMessage` stores `Array(UI::Block)`; `post_blocks` accepts bare `Enumerable` and casts each item. `ViewsOpen` accepts the current modal directly. | Add typed payload overloads, remove casts from the new path, and validate at the request boundary. |
| Components | Helpers return concrete nodes, but the component base types only include macros and aliases. `ButtonActions` derives IDs from display text. | Keep rendering as ordinary typed Crystal methods. Make action IDs independent of labels. |
| Inbound data | Block actions and view submissions mostly expose `JSON::Any`; BlockAction requires fields such as channel and state that vary by source. | Add tolerant inbound DTOs and typed values separately from outbound layout types. |
| Tests and docs | UI tests cover a small subset and often compare JSON strings. Offline WebMock tests, fixtures, subprocess entrypoint tests, formatting, Ameba, and docs CI already exist. | Extend this infrastructure. Add compile contracts and semantic JSON assertions. Replace the README UI example with surface-specific examples. |

Relevant source entry points:

- [UI bases and component contracts](../src/slack/ui/component.cr)
- [Text macro](../src/slack/ui/dynamic_text_composition.cr)
- [Section](../src/slack/ui/blocks/section.cr), [Actions](../src/slack/ui/blocks/actions.cr), and [Input](../src/slack/ui/blocks/input.cr)
- [Plain text input](../src/slack/ui/block_elements/plain_text_input.cr) and [Modal](../src/slack/ui/surfaces/modal.cr)
- [Type aliases](../src/slack/types/type_alises.cr)
- [Message endpoint](../src/slack/api/endpoints/chat_post_message.cr) and [Modal helper](../src/slack/api/helpers/modal.cr)
- [Entry point checks](../spec/entrypoints_spec.cr) and [Offline HTTP checks](../spec/offline_http_spec.cr)

The current Slack reference specifies 25 elements for Actions and 24 characters
for each modal title, submit, and close label. Submit is required when the modal
contains input blocks; close is optional. Plain text input minimum length accepts
0–3000 and maximum length accepts 1–3000.
[Actions](https://docs.slack.dev/reference/block-kit/blocks/actions-block/),
[Modal views](https://docs.slack.dev/reference/views/modal-views/),
[Plain text input](https://docs.slack.dev/reference/block-kit/block-elements/plain-text-input-element/)

Baseline validation: `crystal spec` passed with 187 examples, zero failures, and
zero errors. This establishes the existing baseline, not Block Kit completeness.
Small isolated compiler probes also confirmed that a plain-text-only parameter
rejects a markdown type, and that a generic enumerable can be copied into a narrow
union collection through a typed `add` method without casts. Directly storing
`Array(ConcreteNode)` as `Array(NodeA | NodeB)` failed. A method restriction alone
did not expose that storage error, so future compile tests must exercise storage
and serialization. The probes were temporary and are not a production prototype.

## 3. Public interfaces

Keep `Slack::UI` as the public namespace. Provide two ways to build the same
values: explicit constructors and a small builder API. Constructors are the
canonical contract. Builders call them and do not maintain a second schema.

### 3.1 Explicit value construction

Use named arguments for required content and identifiers. Expose plain text and
Slack markdown as `CompositionObjects::PlainText` and `CompositionObjects::Mrkdwn`.
Convenience functions `UI.plain` and `UI.mrkdwn` return these types. Do not infer
formatting from punctuation or use a `markdown : Bool` switch in new APIs.

Proposed final syntax, to be made executable under distinct prototype names in
phase 0. These examples do not imply that current mutable types can also serve
as checked values; §8 defines the required coexistence proof.

```crystal
require "slack/ui"

approve = Slack::UI::BlockElements::Button.new(
  text: Slack::UI.plain("Approve"),
  action_id: "request.approve",
  value: "request-42"
)

section = Slack::UI::Blocks::Section.new(
  text: Slack::UI.mrkdwn("*Leave request* from Morgan"),
  accessory: approve,
  block_id: "request.summary"
)
```

Preserve valid Slack alternatives. For example, Section must support text only,
fields only, and both together. Use separate initializer overloads for those
shapes; do not expose a zero-content initializer. Require an element collection
for Actions. Validate non-emptiness when its size is dynamic.

Keep `action_id` optional in low-level Button and PlainTextInput constructors,
as Slack permits. Routing-oriented component helpers require explicit action IDs
as a library policy and explain why. Omitted block IDs remain legal. Validate
lengths and uniqueness only for supplied IDs, with action IDs unique within their
containing block. Include a valid omitted-ID link button in wire fixtures.
[Button fields](https://docs.slack.dev/reference/block-kit/block-elements/button-element/)

### 3.2 Surface builders

Use explicit yielded builder objects so ordinary Crystal loops, conditionals,
and method calls work. Avoid a macro language that changes name lookup or hides
control flow. Builders expose `add`, `add_all`, and a small set of useful helpers.
All methods have type restrictions and explicit result types.

```crystal
# Proposed API; not available in the current release.
message = Slack::UI.message(fallback_text: "Morgan requested leave.") do |ui|
  ui.add(section)
end

modal = Slack::UI.form_modal(
  title: Slack::UI.plain("Leave request"),
  submit: Slack::UI.plain("Send"),
  callback_id: "leave_request"
) do |ui|
  ui.input(
    label: Slack::UI.plain("Reason"),
    block_id: "request.reason",
    element: Slack::UI::BlockElements::PlainTextInput.new(
      action_id: "reason"
    )
  )
end
```

Separate `display_modal` and `form_modal` constructors. A display modal accepts
only non-input modal blocks and may omit submit. A form modal accepts input blocks
and requires submit. Both serialize the Slack discriminator `modal`. This small
distinction catches missing submit at compile time without tracking every builder
step in a generic type. A form modal may also contain no input blocks.

Provide `UI.home` with its own block set. Do not model Home as a modal with unused
title and submit fields. Treat Message as a reusable content payload, with fallback
text and blocks; channel, token, thread, and HTTP options belong to API requests.

For messages, support explicit fallback text and a separately named choice to let
Slack derive accessible text. Do not silently generate a partial summary in the
library. Slack documents both accessibility approaches.
[Message accessibility](https://docs.slack.dev/block-kit/#accessibility-considerations)

### 3.3 Collection ergonomics

Accept homogeneous arrays, heterogeneous arrays, tuples, and typed enumerables
through `add_all(items : Enumerable(T)) forall T`. Explicitly check declared `T`
against the accepted item-type set before iteration, then copy each item through
the same restricted `add` method. Internal storage uses the declared slot union.
Do not require callers to cast nodes or spell an array union for ordinary use.
Reject an enumerable whose item type contains an unsupported member, even if a
particular runtime collection happens to contain only supported members.

Restricted `add` alone does not prove that rule: a custom
`Enumerable(Allowed | Forbidden)` can implement `each` by yielding only `Allowed`,
which Crystal may infer more narrowly than declared `T`. Phase 0 must prove a
small type-level guard for concrete types, unions, and nested specializations.
Use the same guard in direct collection constructors and builders. Retain paired
valid/invalid custom enumerable fixtures, including this narrower-yield case;
do not rely on consumers annotating their `each` block signatures.

Keep builder mutation local. `build` returns a stable value snapshot. Later use
of the builder, mutation of the original input arrays, or mutation of a collection
returned by a getter must not change an already built payload.

## 4. Abstractions and responsibility boundaries

| Layer | Responsibility | Must not own |
| --- | --- | --- |
| Composition objects | Text, confirmation, options, filters, and related small values | Parent layout or HTTP |
| Elements | Interactive or visual children, with their own fields | Whole-message state or application handlers |
| Blocks | Layout and permitted child slots | Tokens or request routing |
| Surfaces | Valid block sets, envelope fields, and layout-wide validation | Endpoint transport |
| Builders | Convenient typed assembly and collection normalization | An alternative JSON schema |
| App components | Domain-specific composition of supported values | New Slack wire discriminators |
| Inbound DTOs and parsers | Decode external interaction data and preserve unknown variants | Outbound construction invariants |
| API endpoints | Request envelope, validation before send, transport, and response parsing | Rendering application UI |

Prefer small structs with getters for outbound values. Use classes where recursive
structures or compiler behavior require references, notably future rich text
trees. Do not force all nodes to inherit an abstract struct just to share text
macros. Crystal modules with abstract methods can express a small shared contract,
but protocol acceptance is controlled by closed unions of supported wire types.

Keep `Block` and `BlockElement` only if shared behavior justifies them; neither
should be the accepted type of every child slot. A common serialization method
does not establish Slack compatibility.

Reusable components need no mandatory base class. An app method can return one
concrete block, a narrow union, or a typed collection of blocks. A reusable
component can also define `render_into(builder : MessageBuilder) : Nil` when it
needs to emit several blocks. Do not add a catch-all `add(component)` that converts
an arbitrary object's JSON into accepted blocks. Components inherit the target
builder's restrictions by calling its typed methods.

Preserve old component bases through migration adapters where useful. Replace
label-derived IDs with explicit IDs supplied by app code. Keep business actions,
localization, and callback routing in the application.

## 5. Types and compile-time guarantees

### 5.1 Model semantic differences as types

- Separate `PlainText` and `Mrkdwn`; only the former exposes `emoji`, and only the
  latter exposes `verbatim`. `Text` is their union where both are legal. The text
  object's type and legal fields come directly from Slack's reference.
  [Text objects](https://docs.slack.dev/reference/block-kit/composition-objects/text-object/)
- Emit each wire `type` from a fixed constant or method. Do not accept it as a
  constructor argument or provide a setter.
- Use enums for finite choices such as button style and dispatch triggers, with
  explicit JSON string conversion. Do not rely on enum `to_s` for wire encoding.
  Enums reject unrelated types statically, but `Style.new(99)` can still construct
  an unnamed enum value. Check membership in the owning constructor's shared
  validation rule and report a normal validation issue. If flags are introduced,
  check allowed combinations as well. Do not call invalid values unreachable.
  [Crystal enum validation](https://crystal-lang.org/api/1.21.0/Enum.html)
- Use `Int32` for bounded Slack integer fields, followed by range checks. A small
  machine integer is not a substitute for Slack's numeric constraint.
- Use `T | Nil` only when absence is legal. Keep absent, false, zero, and empty
  values distinct where the protocol distinguishes them.
- Introduce separate select types for static, external, user, conversation, and
  channel sources; distinguish single and multiple selection. Do not create one
  select with a string type and every possible optional field.
- Give incompatible option shapes separate types or constructors. For example,
  plain-text-only menu options must not accept markdown-capable checkbox options
  indiscriminately. Add the precise variants with the first consuming element.

### 5.2 Express placement with narrow unions

Define `SectionAccessory`, `ActionsElement`, `InputElement`, and `ContextElement`
near their owning blocks. Define `MessageBlock`, `HomeBlock`, `ModalBlock`, and
`DisplayModalBlock` near surface contracts. Include only implemented members whose
placement has been checked. Do not populate them from all subclasses or from a
runtime discriminator registry.

Placement can depend on both parent and surface. When a new child has different
surface rules, an outer block union alone is insufficient: a broad `Input` or
`Actions` can conceal that child. Preserve this distinction in the composite type,
using a constrained generic child union or distinct variants. For example, a
surface can accept `Input(HomeInputElement)` without accepting every possible
`Input(T)`. The surface builder normalizes accepted children into that declared
union. Do not erase the child type before surface validation.

Phase 0 must prove a representative nested restriction with actual compiler
fixtures, including homogeneous and heterogeneous arrays/tuples, component output,
already normalized inputs, optional accessories, and direct constructors. Use
explicitly synthetic surface restrictions for compiler-only proofs where Slack
placement is unverified. Prefer explicit aliases and
overloads over a general capability framework. Reuse surface-independent blocks
unchanged. If generic specialization makes the public API or compile cost too
large, use a few explicit composite variants with shared private serialization;
retain the rejection tests as the decision criterion.

Do not assume all input blocks are modal-only. The current Input documentation
also links Home input usage. Check each child's supported parent and surface,
and record uncertain or restricted combinations as unsupported until verified.
[Input block](https://docs.slack.dev/reference/block-kit/blocks/input-block/)

### 5.3 State the limits of static checking

| Rule | Enforcement |
| --- | --- |
| Plain text required for button labels, headers, and modal labels | Compile-time parameter types |
| Missing required content or invalid named field | Constructor overload resolution |
| Invalid child in a slot or invalid block on a surface | Narrow unions, including nested composite types |
| Form modal missing submit | Required argument on form constructor; display block set excludes Input |
| Unrelated style type or mixed select-source fields | Enum parameter types and separate select types |
| Unnamed enum values or invalid flag combinations | Local runtime membership validation |
| Text lengths, array lengths, and numeric ranges | Local runtime validation |
| Empty dynamic fields, duplicate IDs, initial options absent from choices | Local runtime validation |
| At most one focused element in a view | Whole-layout runtime validation |
| Workspace permissions, trigger validity, remote resource availability | Slack response handling |

Do not promise compile-time validation of arbitrary strings or dynamic layouts.
Defer literal-validation macros and generic length-encoded strings/arrays. They
would add a second API and often obscure compiler errors. Reconsider only after
real usage demonstrates a benefit.

Crystal checks methods against the members of a union, but generic collection
storage still needs explicit normalization and the declared-item-type guard in
§3.3. Use the compiler as the specification
for the proposed contracts and instantiate every tested path.
[Crystal union types](https://crystal-lang.org/reference/1.20/syntax_and_semantics/union_types.html)

## 6. Validation and serialization

Constructors check each value's local constraints. Surface construction checks
the whole tree. Construction failures expose `issues : Array(ValidationIssue)`
on the validation exception, so applications can report errors without obtaining
an invalid value. Local construction reports issues for that node; a failed
surface build reports layout issues across its otherwise valid children.
Public `validate! : Nil` and `validate : Array(ValidationIssue)` share those rules
for boundary checks; `validate` normally returns an empty array for a successfully
built snapshot. Do not add another mutable schema or a non-raising factory merely
to make that method useful. An issue has
a stable code, a field path such as `blocks[2].elements[0].action_id`, and a short
message. Keep `InvalidUIBlock` as a compatibility exception or a parent of the
new validation exception. Do not expose submitted private values in diagnostics.

Validate before a typed API request sends HTTP. The raw legacy path needs its own
validation adapter; it cannot obtain static guarantees by casting into a new type.
Builders must not serialize partially built state.

Validate applicable string limits, required non-empty content, collection bounds,
ID lengths and uniqueness at Slack's documented scope, one focus target per view,
minimum/maximum relationships, option membership, and cross-field exclusions.
Include unnamed enum values such as `Style.new(99)` in executed regressions and
verify that they produce validation issues before any HTTP request.
For example, Input with file input cannot enable `dispatch_action`; add a separate
non-dispatching constructor/type when file input is implemented. It must permit
omission or explicit false and reject true.
[Input constraints](https://docs.slack.dev/reference/block-kit/blocks/input-block/)

Getters alone do not make arrays immutable. Copy caller collections at construction
and return copies or read-only iteration from payloads. Apply this recursively
when values own nested arrays. Test that retained builder references and caller
arrays cannot change a serialized snapshot. Keep the validation traversal separate
from the serializer, so their responsibilities remain clear.

Use `JSON::Builder` for outbound encoding with explicit discriminators and fields.
Use a consistent optional-field policy: omit absent optionals, retain explicit
false and zero, and emit null only where required. Serialize each object exactly
once into the envelope; never put JSON strings inside `blocks` or `view`.

Do not automatically include `JSON::Serializable` in every outbound type. Its
generated deserialization constructor creates another construction path. Keep
outbound values construction-focused; add an explicit import/parser only when a
use case needs it, with validation before converting to an outbound value.
Inbound DTOs may use `JSON::Serializable` and its deserialization hooks.
[Crystal JSON serialization](https://crystal-lang.org/api/1.21.0/JSON/Serializable.html)

For future types, prefer an honest unsupported status over silently dropping
fields. Defer a general raw-JSON escape hatch. If later required, make it explicitly
unsafe and separate from the statically checked surface API. Never admit an
unknown inbound object automatically into an outbound supported union.

## 7. API integration and interaction interfaces

Add `ChatPostMessage` construction from a typed Message payload and `ViewsOpen`
construction from typed modal payloads. Share envelope assembly between legacy
adapters and the new entry points. Keep rate limiting and transport behavior in
`ApiClient`; a transport redesign is not needed for this work.

An overload on today's mutable, JSON-deserializable `Api::Base` does not make the
whole request a checked value. Phase 0 must show a typed snapshot held separately
from legacy mutable fields, explicit envelope assembly, and validation immediately
before transport. Exercise both `result` and `call`; validating only `call` leaves
a bypass. For each request path, either reject deserialization as unsupported or
route it through validated conversion. Keep the selected storage boundary and its
legacy mutation behavior in the phase 0 decision record.

Add `views.publish` with the Home slice. Add `views.update`, `views.push`, and
`chat.update` in later surface lifecycle slices. Distinguish endpoint-specific
fields such as channel, trigger ID, view ID, and view hash from layout content.
`view.external_id` belongs to the modal/Home payload; the top-level `external_id`
on `views.update` is a request selector. Preserve both meanings and JSON levels.
Include the nested field in a views.open fixture and both levels in a later
update fixture. Check documented value constraints locally; team-wide uniqueness
requires Slack response handling.
[View update arguments](https://docs.slack.dev/reference/methods/views.update/)

Response URL and incoming webhook message envelopes can reuse the Message
payload later without inheriting a `chat.postMessage` request object.

Keep inbound DTOs tolerant of unknown fields and new discriminators. Decode known
actions into a discriminated union and preserve unknown action type plus raw data
in an `UnknownAction` value. Correct channel, state, team, and view optionality
using message, Home, modal, and organization-installation fixtures. Do not require
an outbound Button when parsing a received button action.
[Block action payloads](https://docs.slack.dev/reference/interaction-payloads/block_actions-payload/)

Add a typed state map keyed by block ID and action ID. Known values cover strings,
single and multiple selected options, selected IDs, date/time values, and files as
their elements ship. Preserve missing keys, null selections, and empty selections
as distinct cases where Slack does. Provide nil-safe typed accessors with useful
type-mismatch errors. Keep external data validation at runtime.
Preserve unknown state-entry types with their raw data, separately from
`UnknownAction`, and test them through the public interaction entrypoint.

Ship a small button action decoder and plain text submission accessor with the
first usable interaction slice. Add suggestion payloads and option responses with
external selects, and typed modal error/update/push/clear response actions with
view lifecycle support. A rendering-only feature must be labeled as such in the
support matrix; it is not end-to-end interaction support.
[View interactions](https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload/)

Use stable app-supplied IDs when the application needs predictable routing;
omitted IDs remain valid in low-level wire construction as specified in §3.1.
Check supplied IDs for duplicates within the appropriate block or layout.
Do not regenerate every block ID during view updates: Slack preserves
input state when matching block and action IDs remain stable. Document message
revision IDs separately from view state preservation.
[Modal state preservation](https://docs.slack.dev/reference/views/modal-views/)

Leave signature verification and existing webhook entry points in place. Action
declarations with generic result types, form-to-record binding, and a routing DSL
are later conveniences, not foundational requirements.

## 8. Prerequisite refactors and compatibility

Use a staged migration within the current namespace. Add shared composition types,
new surface payloads, and explicit builders alongside current constructors. Do not
replace the entire repository's initializer or JSON macros.

Phase 0 must record concrete old/new type names before publishing the §3 examples.
Existing `UI::Blocks::Section` remains a legacy mutable type during coexistence.
Prototype the checked counterpart as a distinct type, for example
`UI::Checked::Blocks::Section`, rather than aliasing the old type or adding another
initializer to it. Keep the experimental namespace outside the public entrypoint
until the naming decision is accepted. Explicit conversion validates and copies
the legacy value; typed builders and endpoints accept only the checked snapshot.
An alias cannot remove setters or inherited JSON constructors.

Prove one existing `TextSection.render` return value, its conversion, retained
legacy mutation, and a checked endpoint request together. The old helper retains
its concrete legacy return type until an announced breaking change; the converted
snapshot remains unchanged. Record whether checked names remain permanent or move
to the shorter names in a breaking release. This decision and the endpoint-storage
proof in §7 are required phase 0 exit gates, not later migration chores.

1. Add `src/slack/ui.cr` as an independent UI-only entry point requiring only its
   actual dependencies. Have `require "slack"` include it. Test both require orders
   and ensure UI-only construction works without Slack credentials or HTTP setup.
2. Correct the current serialization and validation regressions with focused
   tests. Changing malformed accepted payloads to fail locally is intentional;
   document each behavior change.
3. Add canonical `PlainText` and `Mrkdwn`, immutable new contracts, and placement
   unions. Keep legacy nested types and constructors behind conversion adapters
   until callers can migrate. A legacy string discriminator must be checked during
   conversion; it cannot acquire a compile-time guarantee retroactively.
4. Make old component helpers delegate to new constructors where their return
   types and valid behavior can be preserved. Where an adapter cannot preserve
   source compatibility, ship the new API alongside it and remove the old one only
   in the announced breaking release. Do not silently change a declared return type.
5. Replace broad API block arrays through new overloads first. Keep legacy overloads
   deprecated and explicitly outside the static-guarantee claim until removal.
6. Move placement aliases out of the general alias bundle. Correct the
   `type_alises.cr` filename with a temporary require shim if direct requires are
   supported. This spelling cleanup is optional and must not hold up the rollout.

Publish a migration guide with old/new examples for TextSection, ButtonElement,
ButtonActions, InputElement, custom components, post_blocks, and modal opening.
State the deprecation window in the release notes before removal. Preserve valid
JSON behavior where possible; never preserve a bug by advertising it as supported.

## 9. Testing, types tooling, and developer workflow

Use Crystal `spec`, the installed compiler, WebMock, and existing CI. A new test
framework or a mandatory Slack workspace is not needed.

| Test group | Required evidence |
| --- | --- |
| Wire fixtures | Semantic JSON equality for minimum and full payloads; correct discriminator, fields, enum strings, and omission behavior |
| Value boundaries | Just below/at/above each documented bound; unnamed enum values and invalid flags; false/zero/nil cases; empty collections; relevant Unicode examples |
| Layout invariants | Duplicate IDs at correct scopes, focus targets, nested restrictions, form submit, and immutable snapshots |
| Compile-pass fixtures | Constructors, builders, homogeneous and mixed collections, custom enumerables, dynamic loops, custom components, standalone requires, and endpoint overloads |
| Compile-fail fixtures | Markdown label, invalid child, invalid surface, nested surface mismatch, declared enumerable union with a forbidden member despite narrower yields, missing required fields, wrong select variant, and forbidden setters |
| HTTP integration | Actual request body reaches a WebMock stub; invalid payload causes no request through result or call; legacy mutation cannot change a checked snapshot; supported request parsing cannot bypass validation; response errors remain distinguishable |
| Inbound fixtures | Message/Home/modal sources, missing optional fields, null and empty state, unknown actions, unknown state-entry types, and future fields |
| Documentation examples | Standalone executable examples compile and serialize without credentials |

Add `spec/support/compile_contracts.cr` as a small process helper, and put executable
fixtures under `spec/fixtures/compile/{pass,fail}/`. Keep the helper separate from
programs it launches. Reuse the consumer require-path setup pattern from existing
entrypoint tests. Invoke `Process.run("crystal", [...])` with explicit arguments,
temporary output paths, and bounded process duration; avoid shell interpolation.

Use `crystal build --no-codegen` for compile-only contracts. Require success for
positive fixtures. For negative fixtures, check nonzero exit and a small stable
diagnostic fragment naming the relevant API/type, not the whole diagnostic. Compile
a paired positive case so broken imports cannot make a negative test pass. Fixtures
that time out, crash the compiler, or fail to load dependencies are harness failures,
not successful negative contracts. Ensure child processes are terminated and reaped.
Fixtures
must call the methods being tested because unused Crystal methods may not be typed.
Use normal executed specs for serialization and validation behavior.

Maintain a small hand-reviewed support manifest with wire type, documentation URL,
date checked, fields supported, parents, surfaces, restrictions, implementation
status, and test/example paths. Use statuses `unsupported`, `partial`, and
`supported`, with separate inbound status. A small check can verify referenced
paths and required metadata. Do not generate all implementation code from it or
treat manifest agreement as proof that a Slack rule is correct.

Keep CI offline: `crystal spec`, `crystal tool format --check`, Ameba, and
`crystal docs`. Ensure compile contracts run as part of specs, and add a docs/example
compile command if examples are not covered there. Run `crystal tool format` on
changed Crystal files before the format check. Start with the existing supported
compiler, 1.21.0; measure compile-contract cost before adding compiler matrices or
large generated cross-products.

Provide a local example command that emits payload JSON for manual Block Kit
Builder preview. Visual preview is useful for layout and accessibility review,
but is not the test oracle. Documentation drift checks can be manual per feature
release; any future scheduled online check must remain separate from offline CI.

## 10. Iterative delivery sequence

Each phase ends with a usable, reviewable change. Later families can move in
priority after their prerequisites; their interfaces must meet the same contracts.

| Phase | Work | Completion gate |
| --- | --- | --- |
| 0 — Contracts and compiler proof | Record initial support manifest; prototype text types, declared enumerable type guards, nested placement, display/form modals, component reuse, UI-only loading, and legacy-to-checked conversion in isolated fixtures. Prove endpoint snapshot storage, envelope assembly, and pre-transport validation. Record compile cost and concrete old/new names. | Valid and invalid contracts behave as specified on Crystal 1.21.0, including custom enumerables and retained legacy mutation. Resolve composite representation, distinct type identity, and endpoint boundary before making the API public. No catalog expansion yet. |
| 1 — Existing behavior repairs | Preserve baseline tests; repair Section block ID, required collections, Actions limit, modal label rules, integer range handling, and enum wire behavior. Add regressions and release notes. | Existing valid examples pass; known malformed payloads fail locally; correct supported values are accepted. |
| 2 — First typed message slice | Add shared text, confirmation, Button, Section, Actions, a complete Divider, Message payload/builder, custom component examples, validation issues, and typed ChatPostMessage adapter. | Build, inspect, and post an accessible message with a button using offline tests; compile-fail contracts work through constructors and builders. Every omitted current field is declared partial, not silently ignored. |
| 3 — Modal input slice | Complete PlainTextInput, Input, dispatch configuration, display/form modal payloads, ViewsOpen adapter, button action decoding, and plain text submission access. | Offline message action and modal submission round trips; form submit enforced statically; dynamic limits and state optionality tested. |
| 4 — Display and Home slice | Complete Header, Context, image element/block and required image composition objects; add Home builder and views.publish. | Parent/surface matrix tests, accessible labels/alt text, complete Home request fixture, and documented partial inbound coverage if any remains. |
| 5 — Choices and pickers | Add options/groups first; then static selects, overflow, checkbox/radio, user/channel/conversation selects, dates/times, and their multi variants in separate PRs. Add external selects with suggestions and response types. | Each sub-slice includes construction, wire fixtures, placement, limits, typed inbound values, examples, and matrix updates. |
| 6 — Additional inputs and lifecycle | Add number/email/URL/datetime/file inputs in dependency order; add chat.update, views.update/push, and typed modal responses as needed. | Nested surface and dispatch restrictions remain enforced; state-preserving updates, external ID levels, and hash handling have request fixtures. |
| 7 — Rich and specialized content | Add the rich text AST first, then rich text input with typed initial_value and received values; implement file/video/table and newer content families as separate scoped slices. | Recursive encoding and parent rules are tested; feature availability and fields are verified against current Slack docs. No raw-JSON substitute for the rich text dependency. |
| 8 — Consolidation | Finish migrations, remove deprecated construction paths in the announced release, and publish the current supported matrix. | No supported typed path uses arbitrary discriminator strings, broad child casts, or unvalidated mutable arrays. Full suite, compile contracts, lint, format, and docs pass. |

Phase 0 precedes the new public API; phases 1 and 2 can be split into smaller PRs.
Phase 3 depends on the shared values and validation from phase 2. Phase 4 can then
proceed independently of choice controls. Phase 8 is a recurring release activity,
not a reason to wait for every Slack feature.

Phase 0 delivers retained compiler fixtures, small executed proof specs, the initial
support manifest, and a decision record mapping every exit gate to evidence.
Keep prototypes under test support, separate from executable fixtures. UI-only
loading can be proved with an isolated consumer/prototype entrypoint; production
entrypoint changes remain in the prerequisite rollout. Exercise representative
real legacy types in the conversion proof and the current endpoint inheritance
boundary in the request proof without shipping replacement endpoints. Do not do
phase 1 repairs or expand the public catalog to make a prototype pass.

The catalog must remain open to later additions. The current reference lists
newer families such as markdown, table, context actions, cards, containers,
carousels, data views, and task-oriented blocks, as well as rich text and workflow
elements. An index entry is not proof that a feature is generally available or
legal on every surface. Verify its detailed reference and restrictions when its
slice starts. Keep `Mrkdwn` composition text distinct from a Markdown block and
from the rich text AST.
[Block catalog](https://docs.slack.dev/reference/block-kit/blocks/),
[Element catalog](https://docs.slack.dev/reference/block-kit/block-elements/),
[Composition catalog](https://docs.slack.dev/reference/block-kit/composition-objects/)

## 11. Per-feature completion checklist

For each new wire type or supported variant:

1. Record the current official reference, fields, limits, placement, and availability.
2. Add dependent composition objects only as needed by that feature.
3. Add explicit constructors, typed fields, fixed discriminator, and serialization.
4. Add local and parent/surface validation; preserve nested static restrictions.
5. Add positive and negative compiler examples for new structural rules.
6. Add semantic wire fixtures and meaningful value-boundary regressions.
7. Add inbound values and interaction responses when the feature is interactive,
   or declare precisely which interaction support remains partial.
8. Add one complete user example and update support and migration documentation.
9. Run affected specs, compile contracts, formatting, lint, and required CI checks.

## 12. Review questions and implementation risks

The recommended decisions are distinct text types, closed placement unions,
ordinary typed builders, stable payload values, separate inbound DTOs, and phased
compatibility adapters. The review should challenge these choices with concrete
examples rather than expand the initial scope.

- **Nested placement:** Does the phase 0 prototype preserve child restrictions
  after collection normalization and component composition? Is its error readable?
- **Compatibility:** Can adapters preserve existing concrete return types? Which
  changes require a parallel API until a breaking release?
- **Static guarantees:** Does every constructor and API path meet the advertised
  guarantees, or is a legacy/JSON/mutation path being mistaken for a checked path?
- **Protocol accuracy:** Are Home inputs, field limits, option shapes, optional
  interaction fields, and new feature availability grounded in the detailed docs?
- **Incremental scope:** Can phases 2 and 3 ship useful flows without a complete
  catalog, routing framework, generated schema, or transport refactor?
- **Compiler cost:** Do rich unions and nested generic composites cause excessive
  compile time or code size? Record a baseline and prefer explicit variants when
  they improve the API and diagnostics.
- **Snapshot stability:** Can retained arrays, builder objects, or future recursive
  nodes invalidate a payload after validation?

After this plan is complete, launch a new interactive Codex session using
`gpt-6-astra` with reasoning effort `high` in this checkout. Ask it to inspect the
plan, relevant source, and official references, and write a separate first-pass
review with findings ordered by severity, concrete revisions, and any unsupported
claims. It must not implement the plan or rewrite it during review. Leave that
agent session open for follow-up after its review finishes.
