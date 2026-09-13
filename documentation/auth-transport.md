# Authentication transport

The authentication transport sends one HTTP request for each `execute` call. It
does not retry, follow redirects, or inherit proxy settings from the environment.
The caller decides how to handle every response.

## API configuration

The default Web API base URI is `https://slack.com/api/`. Set a different base
URI for GovSlack, a gateway, or a test server:

```crystal
configuration = Slack::Auth::APIConfiguration.new(
  URI.parse("https://api.slack-gov.com/api/")
)

response = Slack::Api::TeamInfo.new(
  token: token,
  configuration: configuration
).call
```

The base URI can contain a path prefix. It cannot contain a query, fragment, or
user information. Method names are appended after one trailing slash. Query
values are encoded by each endpoint. A custom endpoint never falls back to the
default Slack host. Destination and proxy hosts are checked before DNS or any
connection. Use an ASCII DNS name, IPv4 address, or bracketed IPv6 address.
DNS names can have a trailing dot. Invalid labels, brackets, whitespace, controls,
and percent syntax raise a redacted `InvalidConfiguration` error.

API-only applications do not need OAuth client credentials or a webhook signing
secret. The global `client_id`, `client_secret`, and `signing_secret` getters now
return `String?`. The legacy Sign in with Slack path and webhook signing reject a
missing or blank value with a redacted `InvalidConfiguration` error when that
feature is used. Existing applications that read these settings directly must
handle `nil` or narrow the value after their own configuration check.

OAuth installation does not read these global credentials. Create
`Slack::AuthHandler` with an explicit `OAuthConfiguration`, state store, and
transport. The handler validates its nonblank client credentials and HTTPS
endpoints when it is created. See [OAuth installation](oauth-installation.md) for
the session-bound state and callback contract.

## Request-scoped credentials

Use the named-only `tokenless` constructor when a request-scoped transport owns
credential selection. Pass both the transport and the limiter explicitly:

```crystal
def load_conversation(channel_id : String,
                      configuration : Slack::Auth::APIConfiguration,
                      scoped_transport : Slack::Auth::Transport,
                      limiter : RateLimiter::LimiterLike)
  Slack::Api::ConversationsInfo.tokenless(
    channel: channel_id,
    configuration: configuration,
    transport: scoped_transport,
    limiter: limiter
  ).call
end
```

The endpoint waits for the limiter and then calls `Transport#execute`. It does
not add an `Authorization` header. The scoped transport must read the current
credential, add the bearer header inside `execute`, and delegate immediately.
This order prevents a credential from becoming stale while a request waits for
rate-limit capacity.

Tokenless endpoints require both dependencies. A manually constructed endpoint
with `token: nil` fails before dispatch if either dependency is missing. A blank
raw token also fails before dispatch. Existing positional and named raw-token
constructors continue to work. An explicitly supplied limiter is always used;
it does not yield to a limiter cached for the same token and endpoint type.
The `configuration`, `transport`, and `limiter` dependencies are named-only.
This keeps all original optional positional endpoint arguments in their prior
positions. `ConversationsHistory#url_params` remains available and returns the
same encoded parameters as `query`.

`ChatPostMessage.post_blocks` and `Helpers::Modal.open` also have named-only
tokenless overloads. Supply `transport` and `limiter` and omit the token or
access token.

HTTPS is required for remote hosts. Plain HTTP is accepted only for `localhost`,
IPv4 addresses in `127.0.0.0/8`, and the exact IPv6 address `::1`. This rule makes
local development possible and rejects bearer tokens over remote plaintext
connections.

## Transport options

Configure defaults for API wrappers through `Slack.configure`:

```crystal
Slack.configure do |config|
  config.api_transport_options = Slack::Auth::TransportOptions.new(
    connect_timeout: 5.seconds,
    read_timeout: 30.seconds,
    write_timeout: 30.seconds,
    proxy_uri: URI.parse("http://proxy.example:8080"),
    ca_file: "/etc/ssl/certs/private-ca.pem"
  )
end
```

All timeout values must be greater than zero. The connect timeout covers DNS,
TCP connection, proxy negotiation, and the TLS handshake. Read and write
timeouts apply after the connection is ready. A CA file must exist and contain
usable PEM certificates. A configured CA file adds its certificates to the
default trust roots for that transport.

Only an explicit `http` proxy URI is supported. HTTPS destinations use CONNECT.
An HTTP proxy can also route a plaintext loopback destination. Proxy URIs cannot
contain a query or fragment. Optional basic proxy credentials must contain both
a user and a password. `Proxy-Authorization` is sent to the proxy and is removed
from requests inside an HTTPS tunnel.

## Direct transport use

The concrete factory and transport are available from `require "slack"` and
from `require "slack/auth/http_transport_factory"`:

```crystal
factory = Slack::Auth::HTTPTransportFactory.new
transport = factory.build(Slack::Auth::TransportOptions.new)
request = Slack::Auth::TransportRequest.new(
  "POST",
  URI.parse("https://example.test/token"),
  HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
  "grant_type=authorization_code"
)
response = transport.execute(request)
```

You can pass the same factory-built transport to `Slack::AuthHandler`. The
handler validates and consumes the callback state before it sends the token
request. A missing, invalid, expired, wrong-session, or replayed state causes no
HTTP exchange.

Each execute call creates and closes one connection. The implementation gives
every method a request body, including an empty body for GET. It serializes that
request once to the connection and has no retry or reconnect loop.

The response reader parses status and headers before it selects body framing.
HEAD, informational, 204, and 304 responses do not consume representation bytes
based on `Content-Length` metadata. For responses with a body, the reader first
reads and validates the raw representation bytes. It then applies supported
gzip or deflate content decoding and applies the declared text charset last.
HTTP deflate supports zlib-wrapped streams, including checksum validation. The
reader also retains compatibility with raw DEFLATE responses.

## Failures

Invalid URI, timeout, CA, proxy, and method settings raise `ContractError` with
`InvalidConfiguration`. A DNS, TCP, TLS, or proxy failure before application
request bytes leave raises `TransportFailure`. A partial write, timeout, reset,
EOF, or incomplete response after a request can have left raises
`UnknownRemoteOutcome`.

Transport errors do not contain the request URI, headers, body, proxy value, or
raw exception. Do not retry `UnknownRemoteOutcome` unless the application
protocol independently proves that the operation is safe.
