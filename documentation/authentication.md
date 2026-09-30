# Authentication and credentials

Give each credential to the object that uses it. The library has no global settings and reads no environment variables. Block Kit construction needs no credentials.

| Credential | Give it to | Use |
| --- | --- | --- |
| Bot or user token (`xoxb-`, `xoxp-`) | `Slack::Api::Client.new(token:)` | Web API calls with the token's scopes |
| Signing secret | `Slack::Webhooks::Verifier.new` | Verify Events API, command, and interaction requests |
| App-level token (`xapp-`) | `Slack::SocketMode::Client.new` | Open Socket Mode connections; see [Socket Mode](socket-mode.md) |
| App configuration token (`xoxe.xoxp-`) | `Slack::Api::Client.new(token:)` | Manage apps through their manifests; see [App manifests](#app-manifests) |
| Client ID, client secret, redirect URI | `Slack::Auth::OAuthConfiguration` | Install the app with OAuth and refresh rotating tokens |
| Client ID, client secret, sign-in redirect URI | `Slack::OIDC::Configuration` | Sign people in with Slack; see [Sign in with Slack](#sign-in-with-slack) |
| Stored installations | `Slack::Auth::InstallationStore` | Select the credential for each request; rotate and revoke grants |

## Direct tokens and the client

A `Slack::Api::Client` sends requests with one token. The token must have the scopes required by each Slack method that you call:

```crystal
require "slack"

client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])
team = client.call(Slack::Api::TeamInfo.new)
puts team.name
```

Direct token callers own token expiry, revocation, and renewal. The client keeps the token as an `Auth::Secret`; `inspect` shows `[REDACTED]`. An unsuccessful API result raises `Slack::Api::Error`. A configured API base URI or transport changes dispatch, not the token's scopes. See [Web API](web-api.md) for requests, errors, rate limits, and retries.

## Signed requests and installations

Verify each Events API, command, and interaction request with `Slack::Webhooks::Verifier` before you parse it. The verifier checks the timestamp and the `v0` signature against the exact body bytes. See [Verify the request](events-and-interactions.md#verify-the-request) for the parsers and errors.

```crystal
verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(signing_secret))
envelope = Slack::Events.parse(verifier.verify(request).body)
```

Return Slack's URL verification challenge from `Slack::UrlVerification#response` in your framework's HTTP response.

`Slack::Auth::RequestAuthorizer` combines signed request verification with exact installation selection and a stored credential. It uses the verifier on the original bytes before parsing or store access:

```crystal
configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://slack.com/api/"))
authorizer = Slack::Auth::RequestAuthorizer.new(
  "A123", installation_store, api_transport, configuration, verifier
)
context = authorizer.authorize_event(request, Slack::Auth::GrantKey.new(:bot))
context.dispatch("POST", "chat.postMessage", body: request_body)
```

`authorize_command` and `authorize_interaction` accept their signed HTTP requests. `authorize_trusted` is only for a payload already verified and bound to the configured app by trusted application routing. `QueryExtractor` alone does not verify a signature. URL verification does not select an installation.

The selected installation must match exact app, workspace or organization identity, and grant. A workspace key requires a team ID and may have an enterprise ID; an organization key requires an enterprise ID and no team ID. Actor and visible team remain metadata. There is no tenant scan or user-to-bot fallback. If an event names several owners, pass a trusted matching `InstallationKey` or reject it. View interactions use `view.app_installed_team_id` to identify the installed workspace. Missing, contradictory, or duplicate routing fields fail closed.

`RequestContext` keeps a credential reference. Its scoped transport checks the current grant immediately before every send, including an allowed retry, then adds the bearer header. Queued work should create a new context when ready to send. An old context cannot silently switch to a replaced grant. `context.auth_test` is optional identity enrichment; its result cannot change the selected owner.

`RequestContext#client` is a `Slack::Api::Client` without a token. It sends every request through the scoped transport. The client validates and encodes the request, waits for its local pacing, and then the transport checks the current credential and adds the bearer header:

```crystal
context = authorizer.authorize_event(request, Slack::Auth::GrantKey.new(:bot))
context.client.call(Slack::Api::ChatPostMessage.new(channel: "C123", message: message))
```

A replaced or removed grant stops the send with a `ContractError` before any request bytes leave the process. `RequestContext#dispatch` stays available for fenced raw dispatch. `Slack::App::InstallationAuthorizer` uses the same authorizer for app listeners; see [Authorization](app.md#authorization).

Values in a verified interaction, such as a selected channel or a file ID, are user input. They do not prove access or permission. See [Read actions and state](events-and-interactions.md#read-actions-and-state).

## OAuth app installation

`Slack::AuthHandler` installs an app; it does not authenticate a human login. Give it explicit configuration, state storage, and transport.

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

`Slack::App::InstallRoutes` serves these two routes as one `HTTP::Handler`. The application still supplies the binding from its trusted session and still writes the installation to its store. When `session_binding` returns `nil`, both routes answer 400. On a denial, a bad state, or a failed exchange, the handler sends the browser to the `on_failed` path and logs only the error class. Other requests go to the next handler. See [`examples/install_routes.cr`](../examples/install_routes.cr).

```crystal
routes = Slack::App::InstallRoutes.new(handler,
  session_binding: ->(context : HTTP::Server::Context) : Slack::Auth::Secret? {
    current_session(context).try { |session| Slack::Auth::Secret.new(session.id) }
  },
  on_installed: ->(response : Slack::AuthResponse) : String {
    store.store(response.installation_key, response.installation_patch(Slack::Auth::SystemClock.new), nil)
    "/installed"
  },
  on_failed: ->(error : Exception) : String { "/install/failed" },
  install_path: "/slack/install", callback_path: "/slack/install/callback")
HTTP::Server.new([routes, Slack::App::HttpReceiver.new(app, verifier)])
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
  "A123", store, api_transport, configuration, verifier, rotation: rotation
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
lifecycle = Slack::Auth::CredentialLifecycle.new("A123", store, verifier)
prepared = lifecycle.prepare(request)
outcome = lifecycle.apply(prepared)
```

Targeted revocation removes only grants captured at preparation; the bot list contains the bot **user** ID. Uninstall removes credentials and webhook data and retains a tombstone. `apply` retries conflicts a bounded number of times while keeping the captured generation and grant revisions. Several targeted removals are separate transactions, so a storage failure may leave partial cleanup. Retry the **same prepared object** for unchanged remaining targets.

Applications own event ID deduplication, delivery history, and queue persistence. Reuse the original preparation for duplicates and queued work; preparing a duplicate after reinstall could capture a new generation. Slack's event payload has no library installation generation. A delayed first delivery cannot prove that it belongs to earlier credentials, even if preparation sees the current generation. Preserve your own ordering history and defer cleanup when that history is insufficient. There is no durable prepared-delivery serialization in the library.

To revoke credentials in Slack, call the Web API with the credential itself. `AuthRevoke` revokes the calling token. `AppsUninstall` uninstalls the app from the token's workspace and revokes all tokens of that installation. It needs the app's client ID and client secret:

```crystal
client = Slack::Api::Client.new(token: user_token)
client.call(Slack::Api::AuthRevoke.new(test: true)).revoked? # => false; test mode keeps the token
client.call(Slack::Api::AuthRevoke.new).revoked?             # => true

bot_client = Slack::Api::Client.new(token: bot_token)
bot_client.call(Slack::Api::AppsUninstall.new(client_id: client_id, client_secret: client_secret))
```

`AppsUninstall` keeps the client secret as an `Auth::Secret`. These calls do not change the installation store. After a successful call, Slack sends `tokens_revoked` or `app_uninstalled`; clean up the store through `CredentialLifecycle`, as above. Slack returns `bad_client_secret` or `client_id_token_mismatch` as `Api::Error#code` when the client credentials do not match the token.

## Sign in with Slack

Sign in with Slack lets a person sign in to your application with their Slack account. It uses OpenID Connect. It does not install the app and gives no bot token. The result is a verified identity and a user token (`xoxp-`) that has only the sign-in scopes. See [Sign in with Slack](https://docs.slack.dev/authentication/sign-in-with-slack).

`Slack::OIDC::SignInHandler` does the flow. Give it the configuration, a state store, and a transport:

```crystal
require "slack"

configuration = Slack::OIDC::Configuration.new(
  ENV["SLACK_CLIENT_ID"],
  Slack::Auth::Secret.new(ENV["SLACK_CLIENT_SECRET"]),
  URI.parse("https://app.example.com/slack/sign-in/callback")
)
state_store : Slack::Auth::StateStore = Slack::Auth::MemoryStateStore.new
transport : Slack::Auth::Transport = Slack::Auth::HTTPTransportFactory.new.build(
  Slack::Auth::TransportOptions.new
)
sign_in_handler = Slack::OIDC::SignInHandler.new(configuration, state_store, transport)
```

The handler always asks for the `openid` scope. It also asks for `profile` and `email`; set `profile: false` or `email: false` to remove them. The URIs must be absolute HTTPS URIs without user information or fragments. The authorization URI must not set `response_type`, `client_id`, `redirect_uri`, `scope`, `state`, `nonce`, or `team`.

Use two routes and the trusted session binding, as for app installation. Never take the binding from the callback query:

```crystal
# In GET /slack/sign-in:
binding = Slack::Auth::Secret.new(current_session.id)
redirect_url = sign_in_handler.redirect_url(binding)
# Send a framework redirect response to redirect_url.

# In GET /slack/sign-in/callback, with the same trusted session:
binding = Slack::Auth::Secret.new(current_session.id)
sign_in = sign_in_handler.authenticate_user(request, binding)
sign_in.identity.user_id # "U0R7JM"
sign_in.identity.team_id # "T0R7GR"
sign_in.identity.email   # "krane@slack-corp.com", with the email scope
```

`redirect_url(binding, team: "T0R7GR")` adds Slack's workspace hint. A person who is signed in to that workspace goes through directly. The hint does not restrict the workspace.

`authenticate_user` does these steps in this order:

1. It consumes the state. Bad state sends no request.
2. It reads the denial or the code. The state stays consumed.
3. It exchanges the code through `openid.connect.token` with a client that has no token.
4. It fetches the key set and verifies the ID token.

Verification checks the RS256 signature against Slack's key set. Then it checks `iss`, `aud` (and `azp` when there are several audiences), `exp` and `iat` with 60 seconds of leeway, the `nonce` of the attempt, `at_hash` against the access token, and the user, workspace, and subject claims. The handler reads the payload only after the signature is correct. The library requires `at_hash`; Slack sends it in each documented example.

The handler does not decide what a sign-in allows. Your application must:

- Compare `identity.team_id` with your workspaces, if only some workspaces can sign in.
- Decide if an email with `email_verified? == false` is enough.
- Create the session. The handler returns a value and sets no cookie.

Read the profile with the user token:

```crystal
client = Slack::Api::Client.new(token: sign_in.access_token)
profile = client.call(Slack::Api::OpenIDConnectUserInfo.new)
profile.team_name
```

Errors:

| Error | Cause |
| --- | --- |
| `Auth::ContractError` `InvalidState` | Unknown, expired, or used state, another session, or state of an installation attempt |
| `Auth::ContractError` `ReauthorizationRequired` | The person denied access |
| `Auth::ContractError` `InvalidResponse` | A malformed callback, or a key set that Slack did not send correctly |
| `Auth::ContractError` `VerificationFailed` | The ID token failed a check. The error contains no claim and no token |
| `Auth::ResponseError` | Slack rejected the exchange or sent an exchange response without an ID token. `slack_error` is set only for known codes, such as `invalid_code` (`ReauthorizationRequired`) or `bad_client_secret` (`InvalidResponse`) |

With token rotation, the sign-in returns `sign_in.refresh_token` and `sign_in.expires_at`, and the user token expires after 12 hours. The library does not store the refresh token; keep it with the session if you refresh. `refresh` returns a new `UserToken`. Store its new refresh token and discard the old one:

```crystal
token = sign_in_handler.refresh(stored_refresh_token)
token.access_token # the new user token
token.refresh_token # store this one
```

A rejected refresh token raises `Auth::ResponseError` with `ReauthorizationRequired`; sign the person in again. `refresh` does not verify a new ID token. The identity comes from the sign-in.

The handler keeps the key set for 24 hours. It does not read `Cache-Control`. A token with an unknown `kid` causes one more fetch, at most once every five minutes. A failed fetch raises and drops the cached keys, so the next sign-in fetches again. `Slack::OIDC::SignatureVerifier` checks the signature; the default `OpenSSLVerifier` uses the OpenSSL library that Crystal links. Give another implementation with `signature_verifier:`. See `examples/sign_in.cr`.

## App manifests

An app configuration token (`xoxe.xoxp-`) manages apps through their manifests. Give it to the client like any other token. The manifest stays raw JSON (`JSON::Any`); see the [app manifest reference](https://docs.slack.dev/reference/app-manifest). The requests send the manifest as JSON text and keep their own copy.

```crystal
config = Slack::Api::Client.new(token: configuration_token)
manifest = JSON.parse(File.read("manifest.json"))

begin
  config.call(Slack::Api::AppsManifestValidate.new(manifest))
rescue error : Slack::Api::Error
  raise error unless error.code == "invalid_manifest"
  error.details.each { |detail| puts "#{detail.pointer}: #{detail.message}" }
  # /settings/event_subscriptions: Event Subscription requires either Request URL or Socket Mode Enabled
end

app = config.call(Slack::Api::AppsManifestCreate.new(manifest))
app.credentials.signing_secret # Auth::Secret; inspect shows [REDACTED]
config.call(Slack::Api::AppsManifestUpdate.new(app.app_id, manifest)).permissions_updated
config.call(Slack::Api::AppsManifestExport.new(app.app_id)).manifest
config.call(Slack::Api::AppsManifestDelete.new(app.app_id))
```

For `invalid_manifest`, `apps.manifest.validate`, `apps.manifest.create`, and `apps.manifest.update` give each problem in `Api::Error#details`, with a JSON pointer into the manifest. `AppsManifestCreate` returns the client secret, verification token, and signing secret as `Auth::Secret` values; store them securely. The library does not check the manifest schema. Configuration tokens expire after 12 hours; the library does not rotate them (`tooling.tokens.rotate` is available through the generic call). See `examples/app_manifest.cr`.

`AppsEventAuthorizationsList` reads the installations that can see an event, from the envelope's `event_context`. It needs an app-level token (`xapp-`) with `authorizations:read` and pages with `Client#each_page`. Each item is a `Slack::Events::Authorization`.

## Transport settings and failures

`APIConfiguration` defaults to `https://slack.com/api/` and supports an explicit alternate base URI. API-only use needs no OAuth client credentials or signing secret. Pass the configuration and transport to `Slack::Api::Client`:

```crystal
transport = Slack::Auth::HTTPTransportFactory.new.build(
  Slack::Auth::TransportOptions.new(
    connect_timeout: 5.seconds, read_timeout: 20.seconds,
    write_timeout: 20.seconds
  )
)
client = Slack::Api::Client.new(
  token: ENV["SLACK_BOT_TOKEN"],
  configuration: Slack::Auth::APIConfiguration.new(URI.parse("https://api.slack-gov.com/api/")),
  transport: transport
)
```

`TransportOptions` also accepts `proxy_uri` and `ca_file`. Proxy use is explicit; environment proxy settings are not inherited. Only HTTP proxy URIs are supported, with CONNECT for HTTPS destinations. Destination and proxy URI validation happens before connection; remote destinations require HTTPS, while local loopback HTTP is allowed for tests. The concrete transport sends once, follows no redirects, closes its connection on success or failure, and distinguishes `TransportFailure` (no application request bytes left) from `UnknownRemoteOutcome` (the request may have been sent). Do not blindly retry an uncertain write. Timeouts and TLS/CA failures use redacted errors. Transport and parser errors do not include token or remote body text.

`Slack::AuthResponse.parse` and `Slack::RefreshResponse.parse` accept a `TransportResponse` or a body with actual status and headers. They read an IO once, require successful HTTP and `ok: true`, reject malformed known fields, and expose safe `ResponseError` codes and retry metadata. `from_json` assumes HTTP 200; use `parse` when the status is known. Parser success does not verify a session or persist credentials.

## Limits of the offline tests

The specs use synthetic credentials, in-memory stores, and local loopback HTTP. They do not prove that Slack accepts an OAuth exchange or a refresh, the scopes of a token, or the timing of `tokens_revoked` and `app_uninstalled` events. Durable adapters need their own tests; see the [storage test instructions](../spec/support/storage/README.md).

The Sign in with Slack specs use tokens that the OpenSSL CLI signed with a synthetic key. They do not prove that Slack accepts the exchange, the live key set, the live claims, or key rotation. GovSlack sign-in is not tested.
