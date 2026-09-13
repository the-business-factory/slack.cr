# Block Kit Phase 4 independent code review

Reviewed on 2026-09-12 with Crystal 1.21.0 on macOS arm64.
Commit: `9787720b3e5c1afdd10a7d8be71d7fda615bd598`.
Base: `83e7acb23b2a1b93c3acaf5a2a0dfd8bed1114ad` on `robcole/block-kit`.
The worktree HEAD matches the reviewed commit.

**Verdict: no actionable findings.** I found no confirmed correctness bug,
regression, or missing Phase 4 requirement that warrants a correction before
integration. This verdict covers the declared display and Home slice, including
its explicitly partial inbound support. It does not certify the full Block Kit
catalog.

I read AGENTS.md, the plan (including Phase 4 and the completion checklist), the
plan review, the Phase 0 decision record, the Phase 2–4 records, and the support
manifest. I inspected the actual diff, new fixtures and compile contracts, and
related surface, validation, legacy conversion, transport, and interaction code.
The historical plan status and Phase 0 reviewer instruction were not treated as
current instructions. No other agent was launched.

The user requested Astra High. The available session tools do not let me select
or verify that runtime. This is an independent review from this session; it is
not represented as a verified Astra High review.

**Protocol and implementation assessment**

- **Header and Context:** Header enforces PlainText, 150 characters, a 255-character
  block ID, and optional Int32 levels 1–4. Context accepts only text objects and
  image elements, checks its ten-element maximum, and preserves the text objects'
  3000-character limit. Its nonempty collection rule is correctly identified as
  library policy. These match the current [Header reference](https://docs.slack.dev/reference/block-kit/blocks/header-block/),
  [Context reference](https://docs.slack.dev/reference/block-kit/blocks/context-block/),
  and [text reference](https://docs.slack.dev/reference/block-kit/composition-objects/text-object/).
- **Images and accessibility:** The two Image types remain distinct. Only the
  block accepts title and block ID; block alt text and title are capped at 2000
  characters. Both URL fields allow 3000 characters. The element reference gives
  no alt-text maximum, so imposing the block's limit there would be incorrect.
  Keyword-only overloads reject missing, nil, and simultaneous sources and require
  alt text. SlackFile similarly requires exactly one locator. Nonempty summaries
  and locators are documented policies; meaningful descriptions, actual public
  hosting, file access, and image format are not inferred from strings. See the
  [image block](https://docs.slack.dev/reference/block-kit/blocks/image-block/),
  [image element](https://docs.slack.dev/reference/block-kit/block-elements/image-element/),
  and [SlackFile](https://docs.slack.dev/reference/block-kit/composition-objects/slack-file-object/) references.
- **Placement:** Image elements enter Section accessories and Context, while
  image blocks enter surface block collections. Neither enters Actions or Input.
  All new display blocks are admitted by Message, DisplayModal, FormModal, and
  Home. The official Markdown metadata explicitly lists message, modal, and Home
  availability for [Header](https://docs.slack.dev/reference/block-kit/blocks/header-block.md),
  [Context](https://docs.slack.dev/reference/block-kit/blocks/context-block.md),
  [image blocks](https://docs.slack.dev/reference/block-kit/blocks/image-block.md),
  and [image elements](https://docs.slack.dev/reference/block-kit/block-elements/image-element.md).
  Both [Input metadata](https://docs.slack.dev/reference/block-kit/blocks/input-block.md)
  and [PlainTextInput metadata](https://docs.slack.dev/reference/block-kit/block-elements/plain-text-input-element.md)
  explicitly include Home. The current single-child Input union preserves the
  supported parent/surface rule. Message's Input exclusion is accurately described
  as a library restriction. No additional input family is needed for this phase.
- **Home and publishing:** Home owns the complete documented envelope and excludes
  modal labels and lifecycle flags. It checks 100 blocks, metadata lengths,
  duplicate supplied block IDs, and duplicate focus, while allowing repeated
  action IDs across blocks. Omitted values, false, zero, and empty metadata remain
  distinct. Empty Home blocks and a structured JSON `view` are supported by the
  official [App Home guide](https://docs.slack.dev/surfaces/app-home/), despite the
  method table's JSON-string wording. The guide's direct HTTP example also resolves
  the Home reference's misleading Bolt-only wording. Neither the
  [Home field reference](https://docs.slack.dev/reference/views/home-tab-views/) nor
  the [official shared SDK view types](https://github.com/slackapi/node-slack-sdk/blob/main/packages/types/src/views.ts)
  documents a Home external-ID length limit. Hash and interactivity_pointer are
  optional opaque request strings in [views.publish](https://docs.slack.dev/reference/methods/views.publish/).
  The implementation puts external_id inside view and both opaque fields outside it.

**Snapshot, API, and compatibility boundaries**

The collection constructors copy their inputs, and getters return copies. Nested
Context, Section fields, Actions, and dispatch configuration expose no mutable
array owned by the snapshot. Builders can be reused without changing built
values. Both new Enumerable guards inspect declared T before iteration, including
the narrower-yield counterexample from the plan review.

At [checked_views_publish.cr:21](../src/slack/api/endpoints/checked_views_publish.cr#L21),
the request takes a Home snapshot. Validation runs before serialization, result,
and call, with the nested view prefix applied by validate. The public request has
no mutable setters or JSON constructor. The private bridge at
[views_publish_descriptor.cr:2](../src/slack/api/endpoints/views_publish_descriptor.cr#L2)
retains Api::Base transport behavior without exposing its mutable fields as the
checked request API. An independent consumer probe confirmed that the descriptor
cannot be referenced publicly.

The descriptor uses api_client, so configured host/prefix, bearer headers, injected
transport, and limiter remain effective. The body contains the checked envelope
only. Repeated sequential result/call access reuses the HTTP result. The response
model preserves the complete returned view as JSON::Any; API failures pass through
the existing ResponseHandler and Slack::Errors::Api. No new response-layout
decoder is implied.

Legacy placeholder types, concrete helper return types, and existing adapters
remain intact. The Section accessory expansion does not widen its legacy
conversion beyond Button. Earlier checked message/modal contracts still compile
and pass their executed checks.

The inbound description at
[block-kit-phase-4.md:138](block-kit-phase-4.md#L138)
is appropriately limited: typed ButtonAction, typed plain-text state, raw dispatched
text actions, unknown state values, and raw Home view content. Optional channel,
view, and state handling agrees with the [block_actions reference](https://docs.slack.dev/reference/interaction-payloads/block_actions-payload/).
The existing state access preserves absent, null, and empty distinctions consistent
with Slack's [full-state contract](https://docs.slack.dev/changelog/2020/09/01/full-state-on-view-submisson-and-block-actions/).
The example identifies its synthetic interaction as already verified and directs
HTTP consumers to process_interaction. It does not claim a new acknowledgment or
lifecycle framework.

**Independent validation**

- Affected checked UI, publish, transport injection, Home interaction, manifest,
  and Phase 4 compile specs: **184 examples; no failures, errors, or pending;
  22.0 seconds**. This includes all 42 Phase 4 compile/execution examples and the
  offline Home example.
- Phase 2 and 3 compile contracts, checked message/modal endpoint specs, existing
  Block Kit interaction specs, and public entrypoints: **119 examples; no failures,
  errors, or pending; 37.18 seconds**. These also execute the earlier offline
  message and modal examples.
- Five additional temporary consumer compiler probes: private descriptor access,
  modal-only Home fields, and image-element Message placement fail for the intended
  reasons; both UI/core require orders compile. Temporary files were outside the
  checkout and removed after use.
- `crystal tool format --check` and the reviewed commit range's `git diff --check`
  passed. No formatting mutation was performed.

Test processes cleared the named Slack credential environment variables. Request
checks used synthetic credentials and injected offline transports. No live Slack
API request was made. I did not rerun the full 610-example suite, Ameba, or docs;
their supplied passing results remain reported implementation evidence.

**Coverage qualifications and optional improvements**

No correction is required by this review. Two small test improvements are optional:

- Retain a negative consumer fixture for the descriptor's private visibility.
  The independent probe passed, but the committed Phase 4 contracts do not guard
  against a future removal of `private` at the descriptor declaration.
- The duplicate-focus cases at
  [checked_views_publish_spec.cr:43](../spec/api/checked_views_publish_spec.cr#L43)
  fail at builder.build, before request construction. Their two entrypoint labels
  therefore describe construction-time rejection, not two exercised endpoint
  validation paths. They can be consolidated or named more precisely. The empty-user
  cases at line 30 do exercise both endpoint paths and assert zero requests, and
  source inspection confirms the independent boundary checks.

No visual preview, screen-reader exercise, image fetch, or remote acceptance check
was performed. Slack still determines image access, app availability, external-ID
uniqueness, and hash validity. Local field checks also do not guarantee acceptance
under the aggregate view-size ceiling reported by the
[views.publish error reference](https://docs.slack.dev/reference/methods/views.publish/).
These are residual limits, not evidence that a reviewed request fails.

Only this review file was added. Implementation, tests, and existing documentation
were not modified; no commit, merge, rebase, or publication was performed. This
interactive session remains available for follow-up; no terminal-close or
session-close action was taken.
