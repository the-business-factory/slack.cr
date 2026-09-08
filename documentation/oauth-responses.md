# OAuth response parsing

Require the parsers directly until package integration is complete:

```crystal
require "./src/slack/oauth/auth_response"
require "./src/slack/oauth/refresh_response"

body = %({"ok":true,"app_id":"A1","team":{"id":"T1"},"access_token":"synthetic-token","token_type":"bot","scope":"commands","bot_user_id":"UB1"})
response : Slack::AuthResponse = Slack::AuthResponse.parse(body)
key : Slack::Auth::InstallationKey = response.installation_key
patch : Slack::Auth::InstallationPatch = response.installation_patch(Slack::Auth::SystemClock.new)
```

Run this example from the repository root. It parses synthetic data and makes no HTTP request. The application must validate callback state before exchanging a code. The parser does not authenticate a browser session, send requests, or save credentials.

## Parser interface

Both `Slack::AuthResponse` and `Slack::RefreshResponse` expose:

```crystal
.parse(body : String | IO, http_status : Int32 = 200,
       headers : HTTP::Headers = HTTP::Headers.new) : self
.parse(response : Slack::Auth::TransportResponse) : self
.from_json(body : String | IO) : self
```

Use `parse` with the actual HTTP status and headers. `from_json` assumes HTTP 200 and cannot detect an HTTP error. Each parser reads the body once. Non-2xx responses cannot produce success, including HTML error pages. Streams do not need seek or rewind support.

A successful JSON object must contain `ok: true`. Required strings must be nonempty. Unknown fields are ignored. Missing or null optional values are accepted. Invalid known field types fail. Each credential requires an access token, its expected token type, and a nonempty scope string. Scopes are split on commas, trimmed, and deduplicated for storage.

Both input forms must contain valid UTF-8, including ignored fields. Supplied optional strings, such as team and enterprise names, must be nonempty. A scope string with only spaces and commas produces an empty scope list. Duplicate JSON keys use the last value, as in Crystal's JSON parser.

## Authorization-code grants

`AuthResponse#installation_key : Slack::Auth::InstallationKey` builds the installation identity. Workspace installs require a team ID. Organization installs require `is_enterprise_install: true` and an enterprise ID. Their team may be absent or null. A supplied team remains visible metadata; it is excluded from the organization key. Team and enterprise names are optional.

`AuthResponse#installation_patch(clock : Slack::Auth::Clock) : Slack::Auth::InstallationPatch` builds a patch with only the supplied credentials and webhook. The store owns record versions. Omitted grants preserve existing grants when the store applies the patch.

- A top-level bot credential requires `bot_user_id` and `token_type: "bot"`.
- A user credential requires `authed_user.id` and `token_type: "user"` in that object.
- A bot-only response may omit `authed_user` or supply only the installer's ID.
- At least one bot or user credential is required.
- Each rotating credential requires both `refresh_token` and positive integer `expires_in` seconds, at most `Int32::MAX`.
- A webhook requires a nonempty `url` and `channel_id`. `configuration_url` is optional.

The normalizer reads the injected clock once per patch and calculates each grant's absolute expiry separately. Webhook bearer URLs and stored credentials use `Slack::Auth::Secret`.

## Refresh grants

Refresh responses require top-level access token, refresh token, positive expiry, scope, and bot or user token type. They do not require app, team, enterprise, or installer identity. Select this parser for a refresh exchange; the body alone does not establish which request was sent.

For a previously stored grant:

```crystal
previous = Slack::Auth::Grant.new("UB1", Slack::Auth::Secret.new("synthetic-old"), ["commands"])
body = %({"ok":true,"access_token":"synthetic-new","refresh_token":"synthetic-refresh","expires_in":3600,"scope":"commands","token_type":"bot"})
response : Slack::RefreshResponse = Slack::RefreshResponse.parse(body)
replacement : Slack::Auth::Grant = response.grant(previous, Slack::Auth::TokenKind::Bot, Slack::Auth::SystemClock.new)
```

`grant(previous : Slack::Auth::Grant, kind : Slack::Auth::TokenKind, clock : Slack::Auth::Clock) : Slack::Auth::Grant` retains the trusted previous subject. It rejects a different token kind or a different explicit bot user ID. The rotation service must supply the stored grant and its kind, enforce refresh ownership, and persist the replacement. Parsing success does not permit retrying a one-time refresh token.

## Safe failures

Both parsers raise `Slack::Auth::ResponseError`, a subclass of `Slack::Errors::Auth`. It exposes `code : Slack::Auth::ErrorCode`, `http_status : Int32`, `retry_after : Time::Span?`, and `slack_error : String?`. It is not a `ContractError` subclass; catch `ResponseError` or the existing `Errors::Auth` base.

Known code/refresh rejection errors map to `ReauthorizationRequired`. Other HTTP, JSON, UTF-8, stream read, and validation failures map to `InvalidResponse`. Only explicitly allowed Slack error names survive in `slack_error`; unknown remote text is discarded. A nonnegative integer `Retry-After` becomes a duration. Invalid or absent values become nil. Retry metadata is informational and does not authorize a refresh retry.

Failures contain no response body, remote exception cause, or arbitrary headers. Response display and inspection redact credentials. Explicit accessors, user JSON serialization, and `Secret#value` expose credentials for application use; do not log them. The OIDC guard and its error subclass remain unchanged.

## Migration

`AuthResponse` now represents authorization-code success only. Use `RefreshResponse` for refresh exchanges. `team`, `authed_user`, top-level bot credentials, and names can be nil. Check them before use:

```crystal
team_name : String? = response.team.try(&.name)
```

Use this example with an `AuthResponse`. Success responses expose getters instead of mutable JSON properties. Automatic `AuthResponse` JSON serialization is removed; save the normalized patch through an installation store. Use `ok?` only after parsing succeeds. Raw JSON is no longer included in authentication errors.

These parsers do not change the existing callback implementation. Its HTTP status handling, state validation, transport injection, and persistence integration remain separate work. Offline fixtures are synthetic and carry provenance in `spec/fixtures/oauth_responses/provenance.yml`. Live consent, organization installs, webhook delivery, and real token rotation remain unverified.
