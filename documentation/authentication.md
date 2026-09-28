# Authentication and credentials

Use `require "slack"`. Choose the path that matches the operation: supply a token for a direct Web API call, verify signed HTTP requests before parsing them, or install an app with OAuth and store the returned grants. UI construction needs no credentials.

## Direct tokens and signed requests

A direct endpoint takes a token with the scopes required by that Slack method:

```crystal
require "slack"

team = Slack::Api::TeamInfo.new(token: ENV["SLACK_BOT_TOKEN"]).call
puts team.name
```

Direct token callers own token expiry, revocation, and renewal. A `Slack::Errors::Api` reports an unsuccessful API result. A configured API base URI or transport changes dispatch, not the token's scopes.

For Events API, commands, and interactions, set the app's signing secret on the trusted HTTP route. Pass the original `HTTP::Request` to `Slack.process_webhook`, `Slack.process_command`, or `Slack.process_interaction`. These verify the signature and timestamp freshness before parsing. Timestamp checks reject stale requests; they do not suppress duplicate deliveries. Keep an application event ID registry if duplicate processing matters. Return Slack's URL verification challenge from `Slack::UrlVerification#response` in your framework's HTTP response.

`Slack::Auth::RequestAuthorizer` combines signed request verification with exact installation selection and a stored credential. It verifies the original bytes before parsing or store access:

```crystal
configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://slack.com/api/"))
authorizer = Slack::Auth::RequestAuthorizer.new(
  "A123", installation_store, api_transport, configuration
)
context = authorizer.authorize_event(request, Slack::Auth::GrantKey.new(:bot))
context.dispatch("POST", "chat.postMessage", body: request_body)
```

`authorize_command` and `authorize_interaction` accept their signed HTTP requests. `authorize_trusted` is only for a payload already verified and bound to the configured app by trusted application routing. `QueryExtractor` alone does not verify a signature. URL verification does not select an installation.

The selected installation must match exact app, workspace or organization identity, and grant. A workspace key requires a team ID and may have an enterprise ID; an organization key requires an enterprise ID and no team ID. Actor and visible team remain metadata. There is no tenant scan or user-to-bot fallback. If an event names several owners, pass a trusted matching `InstallationKey` or reject it. View interactions use `view.app_installed_team_id` to identify the installed workspace. Missing, contradictory, or duplicate routing fields fail closed.

`RequestContext` retains a credential reference. Its scoped transport checks the current grant immediately before every send, including an allowed retry, then adds the bearer header. Queued work should create a new context when ready to send. An old context cannot silently switch to a replaced grant. `context.auth_test` is optional identity enrichment; its result cannot change the selected owner.

Base endpoint wrappers that expose a `.tokenless` constructor can use a scoped transport. Supply both `transport:` and `limiter:`; the endpoint waits for the limiter, then the transport checks the current credential and adds the bearer header. `Slack::Api::ConversationsInfo.tokenless` is one such wrapper. Checked `CheckedChatPostMessage`, `CheckedChatUpdate`, `CheckedViewsOpen`, `CheckedViewsUpdate`, `CheckedViewsPush`, and `CheckedViewsPublish` constructors still require a `String` token; they do not expose this tokenless path. Use `RequestContext#dispatch` for fenced raw dispatch, or supply a token under your own lifecycle policy.

For checkbox interactions, the same signed-request boundary applies. After verification, read `CheckboxesAction#selected_options` or `StateMap#checkboxes_value?`; an empty selection array means the user cleared all choices. See [checkbox handling](block-kit.md#add-checkboxes) and the offline `examples/block_kit_checkboxes.cr` workflow.

For radio interactions, verify the same original signed request before reading `RadioButtonsAction#selected_option` or `StateMap#radio_buttons_value?`. Use `selected_option_presence` to distinguish an absent field from explicit null (no selection). See [radio handling](block-kit.md#add-radio-buttons) and `examples/block_kit_radio_buttons.cr`.

For user selects, verify the original signed request before reading `UsersSelectAction#selected_user`, `MultiUsersSelectAction#selected_users`, or the corresponding StateMap accessors. Presence distinguishes absent and null fields from a present empty multi-selection. See [user selection handling](block-kit.md#select-an-owner-and-reviewers) and `examples/block_kit_users_select.cr`.

For modal business-validation failures, return `Slack::Interactions::ModalErrors#to_json` as the HTTP 200 JSON acknowledgment after verifying the signed submission. It needs no API token. The application owns validation and the three-second acknowledgment deadline. See [modal error handling](block-kit.md#return-modal-validation-errors).

For a modal update on submission, return `Slack::Interactions::ModalUpdate#to_json` as the HTTP 200 JSON acknowledgment after verifying the signed request. It needs no API token; the application owns the three-second deadline. See [modal update acknowledgments](block-kit.md#update-a-modal-in-its-submission-acknowledgment).

For channel selects, verify the original signed request before reading `ChannelsSelectAction#selected_channel`, `MultiChannelsSelectAction#selected_channels`, or the corresponding StateMap accessors. See [channel selection handling](block-kit.md#select-notification-channels) and `examples/block_kit_channels_select.cr`. Modal submission response URLs remain available as raw data; selection does not prove permission to post.

For the next step after a modal submission, return `Slack::Interactions::ModalPush#to_json` as HTTP 200 JSON after verifying the original signed request. No API token or trigger is needed; the application owns the three-second deadline. See [submission push acknowledgments](block-kit.md#push-a-view-in-a-submission-acknowledgment).

For conversation selects, verify the original signed request before reading `ConversationsSelectAction#selected_conversation`, `MultiConversationsSelectAction#selected_conversations`, or their StateMap accessors. See [conversation selection handling](block-kit.md#select-conversations) and `examples/block_kit_conversations_select.cr`. Filters control the displayed list; a selected ID does not prove access or permission to post.

For date/time pickers, verify the original signed request before reading `DatePickerAction`, `TimePickerAction`, or the corresponding StateMap accessors. The received date, time, and optional timezone remain strings. See [picker handling](block-kit.md#choose-a-date-and-time) and `examples/block_kit_date_time_pickers.cr`.

For datetime pickers, verify the original signed request before reading `DatetimePickerAction#selected_date_time` or `StateMap#datetime_picker_value?`. The received value is Unix seconds as `Int64?`. See [instant handling](block-kit.md#choose-an-instant) and `examples/block_kit_datetime_picker.cr`.

For external selects, pass the Options Load URL request to `Slack.process_interaction` so the signature and timestamp are verified before the `BlockSuggestion` is parsed. Then return `Slack::Interactions::BlockSuggestionResponse#to_json` as HTTP 200 JSON within three seconds. A suggestion or selection does not prove that the user may access the option; check access in your application. See [external option handling](block-kit.md#load-options-from-your-app) and `examples/block_kit_external_select.cr`.

For received rich text, verify the signed event or interaction request before reading `Slack::Interactions::RichText::Block`. Mentions in a received tree are text content; they do not prove membership or permission. See [rich text](block-kit.md#show-rich-text) and `examples/block_kit_rich_text.cr`.

For number inputs, verify the original signed request before reading `NumberInputAction#value` or `StateMap#number_input_value?`. The received number remains a string; parse and check it in the application. See [number input handling](block-kit.md#enter-a-number) and `examples/block_kit_number_input.cr`.

For file inputs, verify the original signed submission before reading `StateMap#file_input_value?`. A received file ID or `url_private` does not prove that the app can read the file; downloads need a token with `files:read`. See [file handling](block-kit.md#collect-uploaded-files) and `examples/block_kit_file_input.cr`.

For URL inputs, verify the original signed request before reading `UrlInputAction#value` or `StateMap#url_input_value?`. A received URL is user input. Check its scheme and host in the application before you store, show, or fetch it. See [URL input handling](block-kit.md#enter-a-url) and `examples/block_kit_url_input.cr`.

For email inputs, verify the original signed request before reading `EmailInputAction#value` or `StateMap#email_input_value?`. The library does not check the received address; check it in the application. See [email input handling](block-kit.md#enter-an-email-address) and `examples/block_kit_email_input.cr`.

For rich text inputs, verify the original signed request before reading `RichTextInputAction#rich_text_value` or `StateMap#rich_text_input_value?`. A malformed tree raises `TypeMismatch`. See [rich text input handling](block-kit.md#enter-formatted-text) and `examples/block_kit_rich_text_input.cr`.

## OAuth app installation

`Slack::AuthHandler` installs an app; it does not authenticate a human login. Give it explicit configuration, state storage, and transport. Global `Slack.configure` client credentials or scopes do not configure this handler.

```crystal
require "slack"

oauth = Slack::Auth::OAuthConfiguration.new(
  URI.parse("https://slack.com/oauth/v2/authorize"),
  URI.parse("https://slack.com/api/oauth.v2.access"),
  ENV["SLACK_CLIENT_ID"],
  Slack::Auth::Secret.new(ENV["SLACK_CLIENT_SECRET"]),
  URI.parse("https://app.example.com/slack/install/callback")
)
state_store : Slack::Auth::StateStore = Slack::Auth::MemoryStateStore.new
transport : Slack::Auth::Transport = Slack::Auth::HTTPTransportFactory.new.build(
  Slack::Auth::TransportOptions.new
)
handler = Slack::AuthHandler.new(oauth, state_store, transport,
  bot_scopes: ["commands", "chat:write"], user_scopes: ["users:read"])
```

OAuth URIs must be absolute HTTPS URIs without user information or fragments. The authorization URI may contain other query values, but must not predefine `client_id`, `redirect_uri`, `scope`, `state`, or `user_scope`. The same configured redirect URI is used for authorization and code exchange.

On the install route, obtain an opaque binding from trusted server session middleware and redirect to `handler.redirect_url(binding)`. On the callback route, obtain that binding from the same trusted session and call `handler.authenticate_user(request, binding)`. Never take the binding from a callback query, untrusted header, or unauthenticated cookie.

```crystal
# In GET /slack/install:
binding = Slack::Auth::Secret.new(current_session.id)
redirect_url = handler.redirect_url(binding)
# Send a framework redirect response to redirect_url.

# In GET /slack/install/callback, with the same trusted session:
binding = Slack::Auth::Secret.new(current_session.id)
response : Slack::AuthResponse = handler.authenticate_user(request, binding)
```

State is unique per attempt and consumed once before checking denial or code. A bad session or expired state sends no token request. A valid state remains consumed after denial, malformed code, HTTP error, or storage failure. Start a fresh flow after failure. The handler performs one token exchange without an automatic retry or redirect and parses the actual HTTP status. Application code persists the returned installation.

Use a `StateStore` whose `issue` and `consume` are atomic across every process that can serve these routes. `MemoryStateStore` is synchronized only within one process and loses state on restart. A shared database adapter needs expiry cleanup, access control, and safe logging; a process-local instance cannot coordinate callbacks routed to another process. The memory adapter prunes on issue; schedule `prune_expired` when new install traffic can stop.

## Persist the installation

`AuthResponse` is a validated wire result. Normalize it before storing. The store's `nil` expected version means **insert only** when the key has never existed. For an active update or a tombstone reinstall, pass the complete existing version. A tombstone reinstall advances the generation; omitted grants on an active update stay in place.

```crystal
store : Slack::Auth::InstallationStore = Slack::Auth::MemoryInstallationStore.new
key : Slack::Auth::InstallationKey = response.installation_key
patch : Slack::Auth::InstallationPatch = response.installation_patch(Slack::Auth::SystemClock.new)
previous : Slack::Auth::InstallationRecord? = store.fetch(key)
expected : Slack::Auth::Version? = previous.try(&.version)
saved : Slack::Auth::InstallationRecord = store.store(key, patch, expected)
```

This example uses the in-memory reference adapter; use a durable adapter for deployed installations. Catch `Slack::Auth::ContractError` at the application boundary: a `Conflict` means another writer changed the version, so fetch and decide whether this OAuth result is still appropriate before another store attempt. On a persistence failure, inspect the stored version; a lost acknowledgment does not prove rollback. Do not report installation success until persistence is confirmed. Never log grants, webhook URLs, or exchange bodies.

Bot and user credentials are separate grants. The bot subject is its authenticated **user** ID. Workspace installs require a team ID; organization installs use enterprise identity, with a supplied team only as visible metadata. The normalized patch contains only returned grants and webhook data. A rotating credential needs a refresh token and positive `expires_in`; expiry is computed from the injected clock. `Slack::RefreshResponse` handles refresh results and retains the trusted previous subject. Its parser alone does not save a grant.

Implementers of production state and installation stores should read the [public adapter contracts](../src/slack/auth/ADAPTERS.md). [Storage test instructions](../spec/support/storage/README.md) describe the conformance suite.

## Rotation and recovery

Pass a `RotationService` to `RequestAuthorizer` through `rotation:` and use the **same installation store instance**. New contexts can rotate a due bot or user grant before dispatch. The service starts no background fiber; applications schedule calls. Fresh grants cause no refresh request. A due grant without a refresh token needs new authorization.

```crystal
refresh_client = Slack::Auth::RefreshClient.new(oauth, transport)
rotation = Slack::Auth::RotationService.new(store, refresh_client)
authorizer = Slack::Auth::RequestAuthorizer.new(
  "A123", store, api_transport, configuration, rotation: rotation
)
```

The default refresh margin is five minutes and lease duration is two minutes. One rotation call makes at most one refresh HTTP request. The store marks the lease `Dispatched` before that request. `RefreshBusy` means another owner has the grant; create a new authorization attempt later. A definite allowlisted refresh rejection removes that grant. An uncertain remote result quarantines it and requires new authorization. Even a transport failure proven to have sent no request leaves a durable dispatched fence under this protocol. Do not resend the old refresh token.

If a successful refresh is followed by a local save failure, `RotationPersistenceError#pending` contains the replacement and lease. Retain it securely and call `service.recover(error.pending)` for a bounded **local persistence** retry. Recovery does not call Slack. A lost completion acknowledgment counts as saved only if the installation generation matches, the grant revision increased, and **every field of the stored grant equals the retained replacement**. A newer revision alone is insufficient. Otherwise the original unexpired lease and fence must still permit completion; revocation, replacement, or expiry can require new authorization.

```crystal
begin
  reference = rotation.rotate(query)
rescue error : Slack::Auth::RotationPersistenceError
  reference = rotation.recover(error.pending)
end
```

For recovery across a process restart, the application must securely retain the pending value; the library defines no durable serialization format. Losing it after a remote success can require reauthorization. Only retry local persistence after an uncertain save, never refresh HTTP.

## Revocation and uninstall

`CredentialLifecycle` verifies and prepares signed `tokens_revoked` and `app_uninstalled` requests. It captures event ID, exact owner, installation generation/version, and affected grant revisions before cleanup. For revocation payloads without authorization entries, supply the exact workspace owner from trusted application routing. The service never scans installations.

```crystal
lifecycle = Slack::Auth::CredentialLifecycle.new("A123", store)
prepared = lifecycle.prepare(request)
outcome = lifecycle.apply(prepared)
```

Targeted revocation removes only grants captured at preparation; the bot list contains the bot **user** ID. Uninstall removes credentials and webhook data and retains a tombstone. `apply` retries conflicts a bounded number of times while keeping the captured generation and grant revisions. Several targeted removals are separate transactions, so a storage failure may leave partial cleanup. Retry the **same prepared object** for unchanged remaining targets.

Applications own event ID deduplication, delivery history, and queue persistence. Reuse the original preparation for duplicates and queued work; preparing a duplicate after reinstall could capture a new generation. Slack's event payload has no library installation generation. A delayed first delivery cannot prove that it belongs to earlier credentials, even if preparation sees the current generation. Preserve your own ordering history and defer cleanup when that history is insufficient. There is no durable prepared-delivery serialization in the library.

## Transport settings and failures

`APIConfiguration` defaults to `https://slack.com/api/` and supports an explicit alternate base URI. API-only use needs no OAuth client credentials or signing secret. Set global API transport defaults with `Slack.configure` or pass named configuration and transport arguments on supported wrappers:

```crystal
Slack.configure do |settings|
  settings.api_configuration = Slack::Auth::APIConfiguration.new(
    URI.parse("https://api.slack-gov.com/api/")
  )
  settings.api_transport_options = Slack::Auth::TransportOptions.new(
    connect_timeout: 5.seconds, read_timeout: 20.seconds,
    write_timeout: 20.seconds
  )
end
```

`TransportOptions` also accepts `proxy_uri` and `ca_file`. Proxy use is explicit; environment proxy settings are not inherited. Only HTTP proxy URIs are supported, with CONNECT for HTTPS destinations. Destination and proxy URI validation happens before connection; remote destinations require HTTPS, while local loopback HTTP is allowed for tests. The concrete transport sends once, follows no redirects, closes its connection on success or failure, and distinguishes `TransportFailure` (no application request bytes left) from `UnknownRemoteOutcome` (the request may have been sent). Do not blindly retry an uncertain write. Timeouts and TLS/CA failures use redacted errors. Transport and parser errors do not include token or remote body text.

`Slack::AuthResponse.parse` and `Slack::RefreshResponse.parse` accept a `TransportResponse` or a body with actual status and headers. They read an IO once, require successful HTTP and `ok: true`, reject malformed known fields, and expose safe `ResponseError` codes and retry metadata. `from_json` assumes HTTP 200; use `parse` when the status is known. Parser success does not verify a session or persist credentials.

Sign in with Slack remains unavailable as verified OIDC identity. Do not use decoded claims as an authenticated user.
