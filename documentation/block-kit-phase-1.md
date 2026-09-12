# Block Kit Phase 1 repairs

Status: complete implementation record for Phase 1 on 2026-09-12.

Base integration commit: `d908acca7c75229d90b789a8475a38caca62e544`.
Compiler: Crystal 1.21.0 on `aarch64-apple-darwin25.6.0`.

This release repairs malformed payloads in the current Block Kit types. It does
not publish the checked Phase 0 prototypes, add endpoints, or expand the block
catalog.

## Intentional behavior changes

- Section now serializes a supplied `block_id` and limits it to 255 characters.
  The ID check runs at construction and serialization so a retained setter
  cannot send an overlong value. A supplied `fields` collection must contain
  one to ten text objects. Text-only, fields-only, and combined sections remain
  valid.
- Actions now requires an `elements` argument and rejects nil or empty input.
  Its supported range is one to 25 buttons, instead of one to five. The former
  positional `block_id, elements` order remains available.
- Modal title, submit, and close labels now accept at most 24 characters. Submit
  can be absent when the modal has no Input block and is required when an Input
  block is present. The condition is checked again during serialization, before
  `views.open` transport, because legacy arrays and setters remain mutable.
  Close is optional. The former direct positional constructor and existing
  six-argument modal helper remain available, and a named helper overload permits
  omitted labels.
- Plain text input length fields now use `Int32`. `min_length` accepts 0 through
  3000, `max_length` accepts 1 through 3000, and minimum cannot exceed maximum.
- Button styles and dispatch action triggers use explicit Slack wire strings.
  Unnamed enum values now raise `Slack::Errors::InvalidUIBlock` instead of an
  unreachable-condition error.

Optional values continue to be omitted when absent. Explicit `false` and zero
values remain in serialized JSON. Phase 1 does not change existing mutable
setters or claim the compile-time guarantees reserved for the checked API.

## Compatibility decisions

The production names remain `Slack::UI::Blocks::Section`,
`Slack::UI::Blocks::Actions`, `Slack::UI::BlockElements::Button`,
`Slack::UI::BlockElements::PlainTextInput`, and `Slack::UI::Modal`. Existing
valid named constructors, former positional Actions and Modal constructors, and
six-argument modal-helper calls remain valid. Calls that used nil or empty
Actions elements, an empty Section fields array, Section block IDs longer than
255 characters, labels longer than 24 characters, invalid length ranges, or
unnamed enums now fail locally.

The Phase 0 checked values stay under test support. This release does not load
them from `require "slack"`, add a checked endpoint, or introduce the planned
message and modal builders.

## Validation record

The final validation used synthetic credentials and offline WebMock responses.
No request was sent to Slack.

- `crystal spec`: 293 examples, zero failures, zero errors, and zero pending.
- `crystal tool format --check`: pass.
- `crystal run lib/ameba/src/cli.cr`: 223 files inspected, zero failures.
- `crystal docs`: pass; this compiler reports that LibXML2 sanitization is not
  available.
- `crystal spec spec/block_kit_support_manifest_spec.cr`: one example, zero
  failures. All manifest evidence paths and required metadata are valid.
