**Block Kit plan: independent first-pass review**

Reviewed on 2026-09-12 against branch `next`, commit
`3d69c462877d439ef66dda92def82295abd457f2`, with Crystal 1.21.0 on
`aarch64-apple-darwin25.6.0`. The plan was an untracked file in this checkout.
References below use its line numbers at review time.

The architecture is suitable for phase 0, with two confirmed corrections to its
type guarantees and one smaller API-boundary clarification. I found no reason to
require a complete catalog, a transport rewrite, or a capability framework first.
The public API is not ready to freeze: the plan correctly makes nested placement
a compiler-proof gate, and the migration boundary also needs a concrete proof.

I read AGENTS.md and the entire plan, inspected the UI catalog, macros, component
helpers, aliases, request and interaction types, relevant specs, README, and CI.
I checked the official references linked below and ran isolated compiler probes.
I relied on the supplied baseline result of 187 passing examples; I did not rerun
the full suite. No production source or plan content was changed.

**Findings, in severity order**

**1. Medium — Enums do not reject every invalid finite value at compile time.**

Plan: §5.1, [lines 214–217](block-kit-plan.md#L214); §5.3,
[line 263](block-kit-plan.md#L263); §6, lines 281–296.

The table places invalid finite styles under enums and separate types, without
stating that enum membership needs runtime validation. Crystal accepts an
unnamed integer value as the enum type. This complete probe compiled and ran on
1.21.0:

```crystal
enum Style
  Primary
  Danger
end

struct Button
  getter style : Style

  def initialize(@style : Style)
  end
end

style = Style.new(99)
p! Button.new(style).style.value # => 99
p! Style.valid?(style)           # => false
```

An explicitly typed constructor therefore accepts the invalid value. A wire
conversion alone either rejects it later, falls through, or emits an unsupported
value, depending on implementation. The existing
[Button::Styles](../src/slack/ui/block_elements/button.cr#L3) has an
"Unreachable condition" branch at lines 13–14; it is reachable for such values.
Dispatch triggers use a similar branch at
[dispatch_action_config.cr:17](../src/slack/ui/composition_objects/dispatch_action_config.cr#L17).
Crystal provides runtime membership checks in its
[Enum API](https://crystal-lang.org/api/1.21.0/Enum.html).

Revision: keep enums, but distinguish static rejection of unrelated types from
runtime rejection of unnamed enum values. Check membership in the owning
constructor/shared validation rule, including invalid flag combinations if flags
are used later. Return the normal validation issue rather than a generic
"unreachable" exception. Add an executed regression using `Style.new(99)` and a
no-HTTP assertion. No new value-type hierarchy is necessary.

This is a confirmed limitation of the proposed guarantee, independent of the
already acknowledged generic-storage experiment.

**2. Medium — Restricted `add` alone does not enforce the declared enumerable item-type rule.**

Plan: §3.3, [lines 159–164](block-kit-plan.md#L159); §5.3, lines 274–276;
§9, lines 406–407; phase 0, line 451.

The plan explicitly rejects an enumerable whose declared item type includes an
unsupported member, even when only supported values occur. Calling restricted
`add` for each yielded value is insufficient for that stronger promise. This
probe compiled and printed `1` on 1.21.0:

```crystal
struct Allowed
end

struct Forbidden
end

class BroadItems
  include Enumerable(Allowed | Forbidden)

  def each : Nil
    yield Allowed.new
  end
end

class Builder
  getter items = [] of Allowed

  def add(item : Allowed) : Nil
    @items << item
  end

  def add_all(items : Enumerable(T)) : Nil forall T
    items.each { |item| add(item) }
  end
end

b = Builder.new
b.add_all(BroadItems.new)
puts b.items.size
```

Crystal types the yielded value more narrowly in this implementation of `each`.
Adding an explicit union restriction to its block parameter made the same call
fail. Thus the current proposal's acceptance can depend on the consumer's `each`
signature, not solely on `Enumerable(T)`.

This does **not** demonstrate an unsupported object entering the stored union;
the restricted `add` still protects storage in this probe. It does demonstrate
that the exact public rejection rule is false for the stated mechanism.

Revision: either explicitly check declared `T` against the accepted item types
before iteration, or narrow the documented guarantee to values yielded with the
compiler's inferred types. The former matches the current plan. A small
`check_item_type(T)` method restricted to `Allowed.class` rejected the example
and still accepted its homogeneous array and tuple counterparts in a separate
probe. Phase 0 must extend that proof to supported unions and nested composites;
this single-type guard is not a complete collection implementation.

Add the custom enumerable above to the negative contracts, paired with a valid
custom enumerable. Apply the same policy to canonical collection constructors,
not just builder helpers. Existing
[post_blocks](../src/slack/api/endpoints/chat_post_message.cr#L8) uses broad
`Enumerable` plus a cast and supplies no evidence for the new guarantee.

**3. Low — Clarify the two meanings of view `external_id` before assigning ownership.**

Plan: §7, [lines 329–333](block-kit-plan.md#L329).

The endpoint-field list groups external ID with channel, trigger ID, view ID, and
hash. External ID also belongs *inside* a view definition. Slack documents
`view.external_id` for modal and Home payloads; `views.update` separately accepts
a top-level `external_id` selector. Treating the list as exclusive ownership would
prevent an independently built view from carrying its own external ID, or put it
at the wrong JSON level when opening the view.
[Modal fields](https://docs.slack.dev/reference/views/modal-views/),
[Home fields](https://docs.slack.dev/reference/views/home-tab-views/),
[views.open usage](https://docs.slack.dev/reference/methods/views.open/),
[views.update arguments](https://docs.slack.dev/reference/methods/views.update/).

Revision: explicitly assign `view.external_id` to the surface payload and the
update selector to the request. Include the nested field in the opening fixture
and both levels in a later update fixture. Local code can check the field's
length; team-wide uniqueness belongs to remote error handling. The current
[Modal](../src/slack/ui/surfaces/modal.cr#L8) has no such field, so existing code
does not settle this distinction. This is an ambiguity to correct, not evidence
that the future adapter already serializes it incorrectly.

**Existing risks and required proof, not additional confirmed design flaws**

- **Nested composites remain a real phase 0 gate.** §5.2, lines 235–248, and
  phase 0, line 451, already require this proof. In a synthetic probe,
  `add(block : Input(T)) forall T` failed when `add_all` received a heterogeneous
  tuple yielding `Input(Common) | Input(HomeOnly)`, although each member was
  individually acceptable. Replacing that restriction with an explicit union of
  accepted specializations allowed the tuple and a homogeneous array, normalized
  storage into `Array(Input(Common | HomeOnly))`, and serialized the result.
  A paired `Input(ModalOnly)` call then failed at compilation. This supports the
  plan's explicit-union fallback; it does not prove all combinations. Include
  heterogeneous arrays, component returns, already normalized inputs, optional
  accessories, and direct constructors in the retained phase 0 fixtures. Do not
  repair inference failures with catch-all `Input`, `Block`, or casts.

- **The legacy and checked types need distinct construction boundaries.** §8,
  lines 367–386, and §12, lines 501–504, recognize this risk and allow a parallel
  API. The concrete problem is broader than constructor overloads: current
  `Blocks::Section` inherits `JSON::Serializable` and initializer macros through
  [Block](../src/slack/ui/block.cr#L1) and
  [DynamicTextComposition](../src/slack/ui/dynamic_text_composition.cr#L2).
  [Section lines 24–29](../src/slack/ui/blocks/section.cr#L24) expose setters,
  broad children, nested legacy text types, and a writable discriminator.
  [TextSection.render](../src/slack/ui/components/text_section.cr#L2) explicitly
  returns that concrete type. One unchanged type identity cannot preserve those
  setters and also satisfy a forbidden-setter compile contract. An alias does
  not create a separate identity. Before publishing the example names in §3.1,
  record the actual old/new names and whether old constructors return legacy
  values or validated new values. Prototype one existing helper, conversion,
  retained mutation, and typed endpoint call together. Add this as an explicit
  phase 0 exit gate; it is currently only implicit in the migration discussion.

- **API inheritance needs its own boundary check.**
  [Api::Base lines 11–19](../src/slack/api/endpoints/base.cr#L11) includes the
  JSON and setter-generating macros. Current request fields remain writable, and
  HTTP is performed from `result` in
  [ChatPostMessage](../src/slack/api/endpoints/chat_post_message.cr#L46) and
  [ViewsOpen](../src/slack/api/endpoints/views_open.cr#L12).
  Avoid assuming a new constructor overload makes the entire request immutable.
  Show where the typed snapshot is stored, how request JSON is assembled, and
  where validation runs immediately before transport. Test direct `result` as
  well as `call`, and any supported deserialization path. §6, lines 288–314,
  already calls for these protections; they need endpoint-level evidence.

- **Snapshot and inbound separation are specified adequately, but unproved.**
  §6, lines 299–314, explicitly covers recursive copying and JSON constructor
  bypasses. Test nested getter arrays and retained builders, not only the outer
  blocks array. Future reference-based rich text nodes need equivalent protection
  against mutation and unintended subclass acceptance. §7 correctly keeps
  inbound values separate: current
  [BlockAction](../src/slack/interactions/block_action.cr#L2) requires channel
  and state, while
  [ViewSubmission](../src/slack/interactions/view_submission.cr#L1) requires a
  top-level `response_urls`. The official payload descriptions vary by source
  and require tolerant parsing. Also exercise unknown state-entry types, not
  only `UnknownAction`, through the public interaction entrypoint.
  [Block actions](https://docs.slack.dev/reference/interaction-payloads/block_actions-payload/),
  [View interactions](https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload/).

- **The proposed test-tooling scope is reasonable.** Existing
  [entrypoint specs](../spec/entrypoints_spec.cr#L4) already isolate consumer
  requires, [process helpers](../spec/support/storage/process_helpers.cr#L10)
  demonstrate bounded child-process cleanup, and
  [message specs](../spec/api/chat_post_message_spec.cr#L9) inspect actual
  WebMock request bodies. Extend those patterns. Compiler timeouts or failed
  imports must count as harness failures, not successful negative contracts.
  A manifest should remain documentation, as §9 states. No generated cross-product
  suite or separate framework is justified by this review.

**Protocol checks and unresolved interface questions**

The important numeric and text claims checked out: 50 message blocks and 100 view
blocks, 25 Actions elements, 24-character modal labels, conditional modal submit,
and plain-text input minimum/maximum ranges of 0–3000 and 1–3000. Section supports
text, fields, and both. Plain text and markdown have different legal formatting
fields. These repairs should remain in the early slices.
[Block limits](https://docs.slack.dev/reference/block-kit/blocks/),
[Actions](https://docs.slack.dev/reference/block-kit/blocks/actions-block/),
[Modal](https://docs.slack.dev/reference/views/modal-views/),
[Plain-text input](https://docs.slack.dev/reference/block-kit/block-elements/plain-text-input-element/),
[Section](https://docs.slack.dev/reference/block-kit/blocks/section-block/),
[Text](https://docs.slack.dev/reference/block-kit/composition-objects/text-object/).

The accessibility choice in §3.2 matches Slack's two documented approaches.
Option variants in §5.1 are justified: menu options have stricter text rules than
checkbox/radio options, and option URLs are specific to overflow menus. Input's
file-input rule prohibits `dispatch_action: true`; do not unnecessarily reject
explicit false. Stable input IDs during view updates are also correct despite
the more general block-reference advice to change IDs between revisions.
[Accessibility](https://docs.slack.dev/block-kit/#accessibility-considerations),
[Options](https://docs.slack.dev/reference/block-kit/composition-objects/option-object/),
[Input](https://docs.slack.dev/reference/block-kit/blocks/input-block/),
[State preservation](https://docs.slack.dev/reference/views/modal-views/).

Resolve these questions in the named slices, without expanding initial scope:

1. **Which Home input combinations are actually supported?** §5.2, lines
   250–253, correctly says the Input reference links Home usage. That link lands
   on the general App Home guide; it does not establish an exhaustive child/surface
   matrix. Keep uncertain combinations unsupported as the plan already requires.
   Use explicitly synthetic types for compiler-only placement proofs rather than
   presenting an unverified Slack restriction as a protocol fact.
   [Input usage](https://docs.slack.dev/reference/block-kit/blocks/input-block/),
   [App Home](https://docs.slack.dev/surfaces/app-home/).
2. **Are explicit IDs a library policy or a wire requirement?** §3.1, lines
   86–99, and §7, line 355, emphasize app-supplied IDs. Current Slack references
   mark `action_id` optional for Button and PlainTextInput; the Button reference
   includes a link button without one. Requiring IDs for predictable application
   routing is defensible, but label it as a deliberate support restriction or
   provide the valid omitted-ID constructor shape. Keep uniqueness checks at
   block scope for action IDs.
   [Button](https://docs.slack.dev/reference/block-kit/block-elements/button-element/),
   [Plain-text input](https://docs.slack.dev/reference/block-kit/block-elements/plain-text-input-element/).
3. **What useful diagnostics does `validate` return after eager validation?**
   §6, lines 281–286, makes constructors and surfaces reject invalid values.
   Their later `validate` calls will normally return no issues. Specify whether
   applications receive issue collections from construction exceptions, a builder
   check, or a small non-raising factory. Do not introduce a second mutable schema
   just to make this method useful.
4. **Where does rich text input get its AST?** Phase 6, line 457, includes rich
   text input; phase 7, line 458, introduces the AST. The dependency-order language
   permits reordering, so this is not a fundamental delivery flaw. Make the edge
   explicit: move the AST earlier or move that input later. Its `initial_value`
   is rich text, so a complete typed slice cannot use raw JSON merely to meet the
   phase number.
   [Rich text input](https://docs.slack.dev/reference/block-kit/block-elements/rich-text-input-element/).

**Readiness and validation limits**

Proceed with phase 0 after correcting the enum and enumerable contracts. Resolve
the concrete migration identity and endpoint-storage decisions before accepting
phase 2's public API. Phase 1's focused repairs can proceed independently of a
complete catalog. Phase 2 can be a useful rendering/sending release with inbound
support explicitly partial until phase 3, as the plan allows.

The isolated probes establish the two counterexamples and one workable small
nested-union route. They do not prove a production builder, modal factory,
legacy adapter, recursive immutable tree, or end-to-end request implementation.
They were created outside the checkout under the OS temporary directory. The
complete counterexamples are reproduced above; they require no Slack credentials.
Official documentation was checked online, but no live Slack requests or visual
previews were performed. Newer catalog entries were not individually certified.
The baseline suite is useful regression evidence, not proof of the proposed API.

**Re-review — 2026-09-12 — revised plan approval**

**Verdict: APPROVED FOR PHASE 0.** All three first-pass findings are addressed
in the revised plan. No additional plan changes are required before starting
phase 0. This approves the scoped proof work, not a completed implementation or
the publication of its provisional API.

I reread AGENTS.md and the full revised plan, compared the revisions with the
first-pass review, and confirmed the checkout remains at
`3d69c462877d439ef66dda92def82295abd457f2`. The submitted plan matched SHA256
`2bf2460592fcaacf7f0c90573bdba3998ea2bb2823978736ccef1194e472456f`.
References in this addendum use the revised plan's line numbers; references in
the original review above remain historical references to the original plan.

**Finding dispositions**

| First-pass finding | Disposition | Revised plan evidence |
| --- | --- | --- |
| 1. Enum membership is not wholly static | Addressed at plan level. Unrelated types are rejected statically; unnamed values and invalid flag combinations receive runtime membership checks and normal validation issues. Executed regressions must establish rejection before HTTP. | §5.1, [lines 234–240](block-kit-plan.md#L234); §5.3, lines 291–292; §6, lines 331–332; §9, line 478. |
| 2. Restricted `add` does not check declared enumerable `T` | Addressed at plan level. An explicit declared-type guard is required before iteration in both canonical collection constructors and builders. The narrower-yield counterexample and its positive counterpart must be retained, including union and nested-specialization coverage. Proving the guard is phase 0 work. | §3.3, [lines 170–184](block-kit-plan.md#L170); §5.3, lines 303–306; §9, lines 480–481; phase 0, line 528. |
| 3. View external ID and request selector were conflated | Addressed. The plan assigns `view.external_id` to modal/Home payloads and the top-level update selector to the request, calls for fixtures at the appropriate JSON levels, and leaves team-wide uniqueness to Slack. | §7, [lines 376–384](block-kit-plan.md#L376); phase 6, line 534. |

These dispositions close the requested design corrections. They do not claim the
future implementation has passed the new contracts. The revisions agree with the
compiler counterexamples and official references established in the first pass;
no new compiler experiments or live Slack checks were needed for this disposition.

**Other first-pass concerns**

| Concern or question | Disposition for starting phase 0 |
| --- | --- |
| Nested placement and normalization | Adequately scoped proof obligation. §5.2, [lines 260–276](block-kit-plan.md#L260), now names mixed arrays/tuples, components, normalized inputs, accessories, and constructors. Explicit variants remain an allowed fallback. |
| Legacy versus checked type identity | Adequately specified exit gate. §8, [lines 429–443](block-kit-plan.md#L429), preserves the real legacy Section and helper return type, requires a distinct checked prototype and copying conversion, and requires evidence that retained legacy mutation cannot alter the snapshot. Final public naming remains a phase 0 decision. |
| Endpoint storage, setters, and deserialization | Adequately specified exit gate. §7, [lines 368–374](block-kit-plan.md#L368), requires separate snapshot storage, envelope assembly, pre-transport validation through both `result` and `call`, and rejection or validated conversion of request deserialization. §10, lines 547–550, requires testing the current inheritance boundary without shipping replacement endpoints. |
| Mutable collections and inbound unknown values | Existing recursive snapshot requirements remain in §6, [lines 338–353](block-kit-plan.md#L338). Unknown state-entry types are now explicit in §7, lines 396–402, and §9, line 483. Inbound implementation stays with its interaction slices. |
| Optional IDs and routing policy | Resolved by §3.1, [lines 118–123](block-kit-plan.md#L118), and §7, lines 411–413: low-level optional IDs are preserved, routing helpers may require them, and only supplied IDs are checked at the documented scope. |
| Useful diagnostics after eager validation | Resolved by §6, [lines 311–322](block-kit-plan.md#L311): construction exceptions expose issues; local and layout failures have distinct scopes; later validation normally succeeds for stable snapshots. No second mutable schema is introduced. |
| Home input uncertainty and file-input dispatch | Correctly bounded. §5.2, [lines 268–281](block-kit-plan.md#L268), permits synthetic compiler restrictions and leaves unverified Slack placements unsupported. §6, lines 333–335, expressly permits omitted or false file-input dispatch while rejecting true. |
| Compiler harness failures | Resolved by §9, [lines 486–500](block-kit-plan.md#L486): timeouts, crashes, and dependency failures are harness failures; children must be terminated and reaped; paired positive cases and executed methods remain required. |
| Rich text dependency order | Resolved by phases 6–7, [lines 534–535](block-kit-plan.md#L534): rich text input follows its AST, with typed initial and received values and no raw-JSON substitute. |

I found no new material contradiction or omission introduced by these revisions.
In particular, the public examples are explicitly provisional (§3.1, lines
93–95), and the coexistence rules identify why the prototypes need different
names. The production entrypoint and repair steps in §8 do not expand phase 0:
§10, lines 543–550, explicitly keeps that work in later rollout steps.

Phase 0 must produce retained compiler fixtures, small executed proof specs, the
initial support manifest, and a decision record mapping its exit gates to evidence
(§10, [lines 528 and 543–550](block-kit-plan.md#L528)). Those deliverables are
achievable without implementing the complete first message or modal slice.
The declared-type guard, composite representation, real legacy conversion,
snapshot boundary, UI-only loading, and compiler cost are matters to establish
*during* phase 0. Their absence today is not a reason to block starting the phase.
If a proposed representation fails, the phase must resolve it within the stated
constraints before claiming completion; approval does not waive an exit gate.

Only the plan's status line was changed, from awaiting reviewer approval to
approved for phase 0. Its final SHA256 is:

```text
916413849f056ae22030535d938cc070137c441ca2f37f5f0b74619a63319d14
```

This re-review did not change production source, implement a phase, rerun the
baseline suite, commit, or launch another agent. No further review condition
blocks starting phase 0 under this approved plan.
