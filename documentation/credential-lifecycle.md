# Credential revocation and uninstall

Require the lifecycle service directly:

```crystal
require "./src/slack/auth/credential_lifecycle"
require "./src/slack/auth/storage/memory_installation_store"

store = Slack::Auth::MemoryInstallationStore.new
lifecycle = Slack::Auth::CredentialLifecycle.new("A1", store)
```

Configure the signing secret for the app's trusted HTTP route. With an incoming
`HTTP::Request`, prepare the delivery, then apply it:

```crystal
prepared = lifecycle.prepare(request)
outcome = lifecycle.apply(prepared)
```

Preparation verifies the original signed bytes and timestamp before parsing or
store access. It accepts only `app_uninstalled` and `tokens_revoked` callbacks.
It captures the event ID, event kind, exact owner, installation version, and
revisions of the affected grants. It does not acquire a credential or call Slack.
Cleanup therefore works with expired, revoked, quarantined, or absent credentials.

`process(request, selected_owner = nil)` prepares and applies immediately.
`PreparedLifecycleDelivery` construction also verifies HTTP; there is no unchecked
payload constructor. Its public fields have no setters, and `targets` returns a
copy. Apply requires the same store adapter instance and configured app.

## Select the installation

Authorization entries must identify one exact installation. If several owners
are listed, pass a trusted `InstallationKey` that matches one entry. Workspace
authorization data must agree with an outer workspace ID when it is present.
An organization key retains its enterprise ID and has no workspace ID.

Slack's documented revocation example omits authorization entries. In that case,
pass the exact workspace owner from trusted application routing:

```crystal
owner = Slack::Auth::InstallationKey.new("A1", :workspace, team_id: "T1")
prepared = lifecycle.prepare(request, owner)
```

The app and workspace must match the signed payload. Include the enterprise ID
in the trusted key when applicable. A payload without authorization entries cannot
establish an organization owner. The service never scans for another installation
or uses an actor ID to select one.

## Apply cleanup

Slack's `tokens.oauth` and `tokens.bot` arrays contain user IDs. The bot list must
match the stored bot **user** ID. A bot ID or token string is not a match. Lists
can omit a token kind. The inner `event_ts` is optional for both lifecycle models.
[Slack revocation payload](https://docs.slack.dev/reference/events/tokens_revoked/)

Targeted revocation removes only grants selected during preparation. Unrelated
users, bot grants, and webhook data survive. A removed target is already complete.
A replacement target with a different grant revision raises `ContractError`
with `Conflict`; it is never removed using the old preparation.

Uninstall deletes credentials and webhook data and retains the store tombstone.
It can follow other revision changes within the captured generation, including
token cleanup or refresh completion. Slack does not guarantee uninstall and
revocation delivery order.
[Slack uninstall payload](https://docs.slack.dev/reference/events/app_uninstalled/)

Each mutation uses an atomic version comparison. Apply retries conflicts at most
three times, reading fresh revisions but keeping the captured generation and
target grant revisions. Other store errors propagate. Several targeted removals
are separate transactions: a storage failure can leave partial cleanup. Retry
the same preparation to finish unchanged remaining targets.

| Outcome | Meaning |
| --- | --- |
| `Applied` | This attempt removed at least one grant or deleted the installation. |
| `AlreadyAbsent` | The installation is absent/deleted, or all selected targets are absent. |
| `Superseded` | An active installation differs from the captured generation, or none existed at preparation. |

The store fences old request contexts and refresh leases. A stale refresh cannot
restore removed credentials. Contexts check the fence before each HTTP send;
cleanup cannot recall an HTTP request already admitted for dispatch.

## Delivery ordering limit

Reuse the **original prepared object** for duplicate event IDs and queued work.
Do not prepare a duplicate against a new installation. Apply does not recheck
the HTTP timestamp after preparation. This release provides in-process prepared
objects, not durable serialization or an event-ID registry. Applications own
deduplication and queue persistence; a restarted adapter is a different instance.

Slack's wire payload does not identify our installation generation or grant
revision. An event first received after reinstall or reauthorization cannot be
proved to belong to the earlier credentials. Preparation captures the current
record; it does **not** establish event-time ownership of that generation.
Applications that need protection for such delayed first deliveries must retain
their own ordering/history and defer cleanup when that history is insufficient.
An event timestamp alone does not supply the missing correlation.

A store deletion followed by reinstall advances generation. An OAuth upsert to
an active record does not. Consequently, uninstall prepared before an active
upsert can still delete that generation. Integrations must establish a new
lifecycle through deletion/reinstall when that is the intended operation.

Offline tests cover synthetic payloads, both delivery orders, target isolation,
duplicate and partial cleanup, store conflicts, reinstall preservation, stale
contexts, and stale refresh completion. Live Slack revocation, actual event
delivery, and the combined rotation-service race remain separate validation.
