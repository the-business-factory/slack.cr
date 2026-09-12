# Request authorization

Slack::Auth::RequestAuthorizer verifies a Slack HTTP request before it parses
routing data or reads the installation store. It supports Events API callbacks,
slash commands, shortcuts, block actions, view submissions, and view closures.
URL verification does not select an installation.

## Configure the authorizer

Use an exact app ID, an installation store, one transport, and one API base URI.
Select a bot grant or one user grant for each request. The authorizer does not
fall back from a user grant to a bot grant.

    authorizer = Slack::Auth::RequestAuthorizer.new(
      "A123",
      installation_store,
      transport,
      Slack::Auth::APIConfiguration.new(URI.parse("https://slack.com/api/")),
    )

    context = authorizer.authorize_event(
      http_request,
      Slack::Auth::GrantKey.new(:bot),
    )
    context.dispatch("POST", "chat.postMessage", body: request_body)

The HTTP methods verify the original body bytes first. Slack shortcut payloads
can omit `api_app_id`. For those two categories, the authorizer binds the
verified request to its configured app and signing route. An explicit app ID
must still match. Use `authorize_trusted` only when trusted application code
already verified the request and bound it to the configured app. QueryExtractor
only extracts data; it does not verify a signature or establish that binding.

## Ownership rules

The selected owner comes from installation authorization data. Actor, visible
team, source team, user team, event team, and channel data stay separate. An
organization key contains an enterprise ID and no team ID. A workspace key can
contain both an enterprise ID and a team ID.

For view submissions, view closures, and block actions in a view,
`view.app_installed_team_id` identifies the installation workspace. The outer
team remains visible-team metadata. Enterprise data for a different visible
team cannot establish the installed team's exact enterprise owner, so the
request fails before store access. For other workspace
interactions, agreeing top-level and `team.enterprise_id` evidence is retained;
conflicting evidence fails closed.

If an event lists distinct owners, supply one trusted InstallationKey that
matches an entry or reject the event. Missing IDs, empty IDs, app mismatches,
unknown installation kind, and duplicate command routing fields fail closed.
The authorizer does not scan the store or call auth.test to select a tenant.

## Credential fence

RequestContext stores a CredentialReference, not an access token. Its scoped
transport calls credential_for_dispatch for every send, after the caller has
finished any wait. It then replaces the Authorization header and immediately
uses the injected transport.

The scoped transport accepts only the configured HTTPS origin and API path.
It makes one transport call and does not follow redirects. Credential
replacement, expiry, refresh quarantine, deletion, and reinstall can stop an
old context before its next send.

Call context.auth_test only when identity enrichment is needed. The request is
a POST with a bearer header and no token body. The result cannot change the
selected owner or grant. Its `user_id` must match the stored subject of the
exact selected grant generation and revision, for bot and user grants. A bot's
subject is its authenticated user ID, not its `bot_id`. Identity mismatch and
malformed or unsuccessful responses raise safe typed errors without response
bodies.
