# OAuth installation

`Slack::AuthHandler` starts and completes a Slack app installation. The application owns
the routes, the trusted browser session, and installation persistence.

## Create the handler

Create one handler with explicit dependencies:

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
  bot_scopes: ["commands", "chat:write"],
  user_scopes: ["users:read"])
```

The concrete HTTP transport sends one request without automatic retries or redirects.
Use `TransportOptions` to set timeouts, a CA file, or an explicit HTTP proxy. You can
instead inject an application transport that implements `Slack::Auth::Transport` with
the same one-attempt behavior.

The handler accepts HTTPS URIs only. URIs must be absolute and must not contain user
information or fragments. The authorization URI can contain benign query parameters.
It must not contain `client_id`, `redirect_uri`, `scope`, `state`, or `user_scope`.

## Bind both routes to a trusted session

Get the session binding from trusted application session middleware. Use an opaque,
server-controlled value. Do not use a query parameter, request header, or callback cookie
value that the application has not authenticated.

```crystal
# GET /slack/install
session_binding = Slack::Auth::Secret.new(current_session.id)
authorization_url = handler.redirect_url(session_binding)
redirect_to authorization_url

# GET /slack/install/callback
session_binding = Slack::Auth::Secret.new(current_session.id)
response : Slack::AuthResponse = handler.authenticate_user(request, session_binding)
```

The start route creates a separate state value for each tab. The callback route consumes
that value once. A denial, malformed code, response error, or transport failure does not
restore it. Start a new flow after any callback failure.

The configured redirect URI is used at both OAuth steps. Callback parameters cannot
change it. Keep the start and callback routes in the same application security boundary.

## Store the installation

`Slack::AuthResponse` is the validated wire result. Normalize it and persist the result at
the application boundary:

```crystal
patch : Slack::Auth::InstallationPatch = response.installation_patch(Slack::Auth::SystemClock.new)
key : Slack::Auth::InstallationKey = response.installation_key
# Persist key and patch in the application installation store.
```

Do not treat token exchange as durable installation storage. The application must handle
storage failure and show a safe restart path to the user.

## Select a state adapter

`Slack::Auth::MemoryStateStore` is a synchronized reference adapter. It supports concurrent
fibers in one process. It loses all state on restart and cannot coordinate two processes.
Do not use it when the start route and callback route can use different processes.

Use one shared application-owned `StateStore` instance or a database-backed adapter for
those deployments. Its `issue` and `consume` operations must keep the contract atomic.
Production storage, encryption at rest, access control, and safe logging are application
responsibilities.

The memory adapter removes expired noncolliding entries when it issues new state. Call
`prune_expired` on an application schedule when new authorization traffic can stop. It
starts no background fiber. Expired entries can remain until issue or explicit cleanup,
so the application controls the memory bound.

## Migrate from the old API

Remove these old patterns:

- `Slack::AuthHandler.configure`
- `Slack::AuthHandler.new` without dependencies
- `Slack::AuthHandler.run(request)`
- callbacks that do not pass a trusted session binding

Create explicit configuration, state store, and transport objects instead. Keep the same
handler instance, or equivalent handlers that share the same state store, available to
both routes. Pass the same trusted session identity to `redirect_url` and
`authenticate_user`.
