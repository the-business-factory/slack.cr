# Block Kit Phase 0 decisions

Status: complete proof record for Phase 0 on 2026-09-12.

Reviewed base: `3d69c462877d439ef66dda92def82295abd457f2`.
Approved plan SHA256:
`916413849f056ae22030535d938cc070137c441ca2f37f5f0b74619a63319d14`.
Compiler: Crystal 1.21.0 on `aarch64-apple-darwin25.6.0`.

This record covers test-only architecture proofs. It does not publish a Block Kit
catalog or repair Phase 1 behavior.

## Decisions

### Checked and legacy names

Keep the current mutable type named `Slack::UI::Blocks::Section` during the
compatibility period. Introduce the new value as
`Slack::UI::Checked::Blocks::Section`. These are distinct types. Conversion makes
a validated recursive copy; it does not preserve object identity.

Use the checked namespace during coexistence. In the next announced breaking
release, move the checked values to the shorter `Slack::UI::Blocks` and
`Slack::UI::CompositionObjects` names when the legacy constructors are removed.
Keep explicit migration adapters for the documented transition release. Existing
helpers such as `TextSection.render` continue to return the current concrete
legacy type until that breaking release.

The Phase 0 declarations are under `spec/support/block_kit`. They are not loaded
by `require "slack"` and are not public implementation.

### Text and composite representation

Use separate immutable `PlainText` and `Mrkdwn` structs. The fixed discriminator
and format-specific option belong to each type. Use a closed union only where both
formats are legal.

For nested composites, use an explicit accepted union. It lists each supported
`Input(T)` specialization and the already normalized `Input(A | B)` specialization.
Copy accepted values into an array declared with that union. Do not cast a concrete
generic specialization into a broader specialization. The proof uses synthetic
Common, Modal, Home, and Forbidden inputs because the corresponding Slack Home
placement matrix is not verified for Phase 0.

Every `Enumerable(T)` entry point checks declared `T` against its accepted union
before iteration. Constructors and builders use the same guard. This rejects a
custom `Enumerable(Allowed | Forbidden)` even when its `each` implementation
yields only `Allowed`.

### Migration identity and snapshot ownership

`LegacyAdapter.section` accepts the real return type of `TextSection.render`. It
checks mutable legacy discriminators, converts text and the supported Button
accessory, copies nested fields, and returns the distinct checked Section. Later
legacy mutations cannot affect that checked snapshot. Checked collection getters
return copies.

Builders own mutable working arrays. `build` calls the canonical constructor,
which copies the array. Later builder changes, caller-array changes, and changes
to returned getter arrays do not alter an earlier snapshot.

### Endpoint boundary and storage

Do not inherit the checked request adapter from `Slack::Api::Base`. That base adds
public setters and JSON deserialization to every request. The Phase 0 proof uses
composition:

- `CheckedChatPostMessage` stores a private copy of checked `Message` separately
  from token and channel request fields.
- It assembles the channel, fallback text, and blocks with `JSON::Builder`.
- It validates immediately in both `result` and `call`, before transport.
- It uses a short-lived real `Api::ChatPostMessage` only as the existing
  `ApiClient` transport descriptor. It does not use the legacy block serializer.
- It does not include `JSON::Serializable`; an explicit compiler contract rejects
  request deserialization. A parsed legacy request is not accepted as a checked
  snapshot.

The current `ChatPostMessage.from_json` path is also retained as a negative
compiler fixture. Instantiating it fails at its abstract `Array(UI::Block)` field,
so it is not a supported request parser and cannot produce a checked snapshot.

This isolates inherited legacy mutation while preserving current rate limiting,
headers, URL selection, WebMock coverage, and response parsing. Production
endpoints remain unchanged in Phase 0.

## Exit-gate evidence

| Exit gate | Concrete evidence | Result |
| --- | --- | --- |
| Plain text and markdown are distinct | `pass/text_types.cr`; `fail/mrkdwn_button_label.cr`; executed semantic JSON spec | Pass; markdown is rejected for Button text. |
| Checked values forbid mutation | `fail/checked_setter.cr`; `fail/checked_button_setter.cr`; `fail/checked_section_setter.cr` | Pass; compiler reports missing text, style, and fields setters. |
| Declared enumerable type is checked | `pass/collections_and_surfaces.cr`; `fail/forbidden_declared_enumerable.cr` | Pass; the narrower-yield custom enumerable is rejected by its declared union. |
| Homogeneous and mixed arrays and tuples work | `pass/collections_and_surfaces.cr` | Pass for homogeneous arrays/tuples and heterogeneous arrays/tuples. |
| Nested child restrictions survive collection copying | `pass/nested_surfaces.cr`; `fail/forbidden_nested_surface.cr` | Pass with explicit specialization unions and synthetic placement types. |
| Already normalized composites work | `pass/collections_and_surfaces.cr` | Pass for `Input(FormInputElement)`. |
| Optional accessories and direct construction work | `pass/text_types.cr`; `pass/collections_and_surfaces.cr`; `fail/invalid_accessory.cr` | Pass; valid optional Button accepted and unrelated accessory rejected. |
| Components can return and render into checked builders | `pass/collections_and_surfaces.cr` | Pass for reusable single-block and `render_into` paths. |
| Display and form modal rules are static | `pass/collections_and_surfaces.cr`; `fail/display_modal_input.cr`; `fail/form_modal_missing_submit.cr` | Pass; both emit `modal`, display excludes Input, and form requires submit. |
| UI-only loading needs no credentials | `pass/ui_only.cr`; bounded executed entrypoint spec with Slack variables removed | Pass; it constructs and serializes without loading `src/slack.cr`. |
| Real legacy conversion has a distinct identity | executed proof spec and `pass/legacy_endpoint.cr` | Pass for the actual `TextSection.render` result and Section type. |
| Retained legacy and nested mutations cannot alter snapshots | executed proof spec | Pass for legacy text, field arrays, checked getter arrays, caller arrays, and retained builders. |
| Mutable legacy discriminators are checked | executed proof spec | Pass with normal `legacy.text.type.invalid` issue. |
| Unnamed enum values become normal issues with no HTTP | executed proof spec using `ButtonStyle.new(99)` and WebMock counter | Pass with `button.style.invalid`; zero requests. |
| Checked endpoint storage is separate | executed snapshot proof | Pass after legacy, caller-array, and getter mutation. |
| Envelope assembly uses checked values once | direct `result` WebMock body assertion | Pass for channel, fallback text, and a structured blocks array. |
| Validation runs through `result` and `call` before HTTP | two executed negative endpoint specs | Pass; both return `chat_post_message.channel.empty` and send zero requests. |
| Request deserialization has no checked bypass | `fail/request_deserialization.cr`; `fail/current_request_deserialization.cr` | Pass; checked deserialization is explicitly unsupported and the current inherited parser cannot instantiate its abstract block field. |
| Current endpoint inheritance is exercised | executed legacy setter proof and checked adapter transport specs | Pass; the real current request stays mutable and the adapter avoids inheriting it. |
| Representation, names, identity, and endpoint storage are resolved | Decisions above | Resolved for the phased migration. |
| Phase 0 stays isolated | Git diff and support paths | No production source, endpoint replacement, catalog expansion, Phase 1 repair, push, merge, or publish. |

Fixture paths in the table are relative to `spec/fixtures/compile`.

## Compiler cost

The compile-contract spec uses `crystal build --no-codegen`, a 30-second limit,
an explicit temporary output path, crash detection, dependency-failure detection,
and terminated/reaped child cleanup. Every negative fixture first compiles its
paired positive fixture.

Measured with a warm compiler cache on this worktree:

| Fixture | Time |
| --- | ---: |
| pass/collections_and_surfaces.cr | 227.8 ms |
| pass/legacy_endpoint.cr | 537.3 ms |
| pass/nested_surfaces.cr | 257.4 ms |
| pass/text_types.cr | 239.6 ms |
| pass/ui_only.cr | 241.7 ms |
| fail/checked_setter.cr | 213.9 ms |
| fail/checked_button_setter.cr | 199.6 ms |
| fail/checked_section_setter.cr | 197.8 ms |
| fail/current_request_deserialization.cr | 399.6 ms |
| fail/display_modal_input.cr | 200.0 ms |
| fail/forbidden_declared_enumerable.cr | 240.1 ms |
| fail/forbidden_nested_surface.cr | 193.8 ms |
| fail/form_modal_missing_submit.cr | 217.9 ms |
| fail/invalid_accessory.cr | 197.7 ms |
| fail/mrkdwn_button_label.cr | 196.8 ms |
| fail/request_deserialization.cr | 379.2 ms |

The complete compile-contract spec, including paired recompiles and the executed
UI-only fixture, took 7.82 seconds. The largest unique compile was 537.3 ms. This
cost does not justify a capability framework or generated cross-product suite.

## Validation record and limits

The final validation commands and results are recorded here after implementation:

- `crystal spec spec/block_kit_phase_0_proof_spec.cr`: 13 examples, zero failures.
- `crystal spec spec/block_kit_phase_0_compile_spec.cr --verbose`: 17 examples,
  zero failures; 7.82 seconds.
- `crystal spec`: 218 examples, zero failures, zero errors, and zero pending.
- `crystal run lib/ameba/src/cli.cr`: 196 files inspected, zero failures.
- `crystal tool format --check`: pass.
- `crystal docs`: pass; this compiler reports that LibXML2 sanitization is not
  available.

All HTTP checks use WebMock and synthetic credentials. No live Slack request or
visual preview was performed. The nested Home/modal controls are compiler-only
synthetic restrictions, not claims about undocumented Slack placements. The
manifest reports current public support and does not treat Phase 0 prototypes as
shipped types.
