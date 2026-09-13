# Phase 5 static choices: independent code review

**Verdict: no actionable findings.** I found no confirmed correctness defect,
regression, or missing requirement that requires a correction in this static-choice
slice. The declared partial inbound support matches the implementation. This
verdict does not cover the deferred Phase 5 element families.

Reviewed on 2026-09-13 with Crystal 1.21.0, LLVM 22.1.8, on macOS arm64.
Reviewed commit: `542737fd8f8c5cdc8a9ec369ba193cf9c6b00301`.
Base on `robcole/block-kit`: `165650260f5773610f1c2b551728d30c2234e149`.
Before review, HEAD matched the requested commit, the worktree and index were
clean, and the merge base was the supplied base. HEAD and cleanliness were checked
again before writing this file.

I read AGENTS.md, the complete plan and its per-feature checklist, the plan review,
the Phase 0 decisions, the Phase 2–4 records, the Phase 4 review, the support
manifest, and the Phase 5 static-select record. I reviewed all 77 changed files,
including source, all compile fixtures, all nine JSON fixtures, runtime specs,
test support, the example, and documentation. Related builders, surfaces, legacy
adapters, checked endpoints, and public interaction parsing were also inspected.
Historical Phase 0 review instructions were treated as historical context.

**Protocol assessment.** Current official references were checked independently.

- Option uses plain text for its label and description, with 75-character limits,
  and a unique value with a 150-character limit. Its omission of URL and markdown
  variants is correct for this consuming menu family. OptionGroup has a plain-text
  label capped at 75 and at most 100 options per group. The documented nonempty
  collection policy is explicit. See Slack's [Option reference](https://docs.slack.dev/reference/block-kit/composition-objects/option-object/)
  and [OptionGroup reference](https://docs.slack.dev/reference/block-kit/composition-objects/option-group-object/).
- StaticSelect has the complete documented static-source field set. The source
  overloads enforce options versus groups; each collection permits at most 100.
  Optional action IDs, placeholders, confirmation, focus, and exact initial
  matching agree with the [single-select reference](https://docs.slack.dev/reference/block-kit/block-elements/select-menu-element/).
  MultiStaticSelect adds initial selections and an Int32 selection maximum of at
  least one. Slack gives no maximum for that integer. The implementation checks
  initial count against it and rejects repeated initial values. See the
  [multi-select reference](https://docs.slack.dev/reference/block-kit/block-elements/multi-select-menu-element/).
- Both element references explicitly permit Section, Actions, and Input parents.
  Their current Markdown metadata lists messages, modals, and Home; Input metadata
  includes both menu families on those surfaces. The checked Message Input
  exclusion is correctly documented as a library restriction. DisplayModal still
  excludes Input, and FormModal requires submit. No additional static-source
  feature gate appears in the detailed references. See the [single-select metadata](https://docs.slack.dev/reference/block-kit/block-elements/select-menu-element.md),
  [multi-select metadata](https://docs.slack.dev/reference/block-kit/block-elements/multi-select-menu-element.md),
  and [Input metadata](https://docs.slack.dev/reference/block-kit/blocks/input-block.md).
  The Markdown pages were fetched directly when the browser tool could not open
  those URLs.
- The received option shape agrees with Slack's official [action types](https://github.com/slackapi/bolt-js/blob/main/src/types/actions/block-action.ts)
  and [view-state types](https://github.com/slackapi/bolt-js/blob/main/src/types/view/index.ts).
  The more tolerant absent/null handling is intentional. Cleared single selections
  remain null, and cleared multi-selections remain present empty arrays, consistent
  with Slack's [full-state contract](https://docs.slack.dev/changelog/2020/09/01/full-state-on-view-submisson-and-block-actions/).
  The keyed state access also matches the [view interaction reference](https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload/).

**Construction, placement, and validation.** The four outbound types are checked
structs with getters, fixed wire shapes, and no supported JSON construction path.
Option equality compares the complete value, so initial matching includes text,
emoji presence, and description. Duplicate offered values are checked across
groups, with the second option's full path reported at
[static_select_content.cr:54](../src/slack/ui/checked/block_elements/static_select_content.cr#L54).

[OptionCollection.copy](../src/slack/ui/checked/option_collection.cr#L3) checks
declared Enumerable(T) before copying. Group copying and Actions use the same
policy for their accepted types. Builders delegate to canonical constructors.
The retained negative fixtures exercise forbidden declared members despite narrower
yields; the positive consumer exercises arrays, tuples, custom enumerables,
normalized unions, optional accessories, components, and all four builders.
Additional independent probes confirmed the guard on grouped multi-select initial
options, including a runtime nullable enumerable.

The Section, Actions, and Input slots remain closed unions. The supported Input
children share the same admitted surfaces, so this expansion does not erase a
child-specific surface restriction. Context and direct surface placement still
reject selects. Actions continues to check supplied action IDs at block scope;
surface validators check supplied block IDs at layout scope. Repeating action
IDs across blocks remains legal.

[ViewFocus](../src/slack/ui/checked/view_focus.cr#L3) visits Section accessories,
every Actions element, and Input elements, including PlainTextInput. It reports
each focus target after the first at the correct nested path. Home, FormModal,
and DisplayModal use this traversal. Messages do not inherit a view-only rule.
Both the committed tests and an independent reverse-order probe passed.

Caller arrays and returned collections cannot change the stored option lists,
groups, initial selections, blocks, or built snapshots through the public API.
The nested getter copies remain sufficient because the contained outbound values
are immutable. No casts or broad child base types were added to checked storage.

**Endpoint and interaction boundaries.** All three existing checked request
adapters retain separate surface snapshots, validate before both `result` and
`call`, and serialize structured blocks/views into one request envelope. See
[CheckedChatPostMessage](../src/slack/api/endpoints/checked_chat_post_message.cr#L83),
[CheckedViewsOpen](../src/slack/api/endpoints/checked_views_open.cr#L48), and
[CheckedViewsPublish](../src/slack/api/endpoints/checked_views_publish.cr#L52).
The six new endpoint cases exercise both entrypoints on all three adapters after
mutation attempts and verify the actual offline request body. Existing boundary
rejection, transport injection, response, deserialization, and legacy tests also
passed in the independent full run. Local invalid children fail eagerly; such
construction failures are not evidence of executing an endpoint validation path.

The public JSON and signed HTTP entrypoints reach the new action/state decoders.
Signature and replay verification still run before parsing signed requests.
Selection fields preserve absent, null, and empty distinctions. Missing state
keys return nil; wrong-family access raises TypeMismatch. Malformed known option
members report nested paths and expected/actual types. Received strings and text
discriminators do not inherit outbound length or format restrictions.

SelectedOption retains complete raw option JSON, including future fields.
UnknownAction and UnknownStateValue retain raw unknown objects. Existing raw
actions, state, and view access remains available before typed decoding. The
manifest correctly marks echoed configuration, emoji, descriptions, and view
content as raw or partial. Group objects have no separate received selection
value. No suggestion or response-action support is implied.

Legacy types, helpers, and adapters retain their identities and behavior. The
widened checked child unions require callers to narrow before using a
child-specific method; the migration record explicitly explains this. The UI-only
consumer continues to execute without Slack environment credentials.

**Independent verification.** These are results from this review session:

- Full `crystal spec`: **676 examples, zero failures, errors, or pending;
  1 minute 51 seconds**. This includes the 38 Phase 5 compile/execution examples,
  prior phase contracts, and all four offline examples. The process used synthetic
  Slack credential environment values; HTTP checks used the suite's offline
  transports and stubs.
- Three additional temporary runtime examples passed: nullable initial collections
  with either source, Input-before-Section focus paths, and empty received strings
  plus malformed text-type diagnostics. An initial reviewer-authored probe had a
  JSON syntax error; it was corrected before the successful run.
- Two additional temporary compiler probes rejected broad declared initial-option
  enumerables on the grouped constructor, including a runtime nullable variant,
  with the intended declared-item diagnostic. All temporary probe files were
  outside the checkout and removed.
- `crystal tool format --check` and `git diff --check` for the complete reviewed
  commit range passed. No formatter mutation was performed.

I did not independently rerun Ameba, crystal docs, the separate 193-example subset,
or the example as a separate direct command. Their reported implementation results
remain prior evidence: 437 linted files with no failures, successful docs with the
existing unavailable-LibXML2 notice, 193 passing affected examples, and a successful
direct example run. The example did execute within my full suite.

**Residual limits.** No live Slack API request, visual preview, accessibility
exercise, or remote acceptance test was performed. Local checks do not establish
workspace/app access or acceptance under aggregate payload limits. Large grouped
menus were not stress-tested. The current references do not explicitly settle
remote treatment of an explicitly empty outbound initial_options array; the
implementation preserves it, and its documentation recommends omission for no
initial selection. This uncertainty is not evidence of a defect.

Overflow, checkbox/radio controls, remote-source and ID-based selects, date/time
pickers, external suggestions, and view response actions remain deferred as
requested. The completion checklist is satisfied for the declared static-choice
slice and its stated inbound limits.

Only this review file was added. No implementation, fixture, or existing document
was changed. No commit, merge, rebase, push, publication, or additional agent was
started. No session-close action was taken; this interactive review remains
available for follow-up.
