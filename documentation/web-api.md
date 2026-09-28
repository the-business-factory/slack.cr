# Web API

Call Slack Web API methods with `Slack::Api::Client`. A typed request validates its fields before the send and decodes a typed response. Methods without a typed request use the generic call.

## Minimal example

```crystal
require "slack"

client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])
team = client.call(Slack::Api::TeamInfo.new)
puts team.name
```

The token must have the scope that each Slack method requires. For example, `team.info` needs `team:read`. The client keeps the token as an `Auth::Secret`; `inspect` shows `[REDACTED]`.

## Client

| Method | Use |
| --- | --- |
| `call(request)` | Sends one typed request and returns its response model. |
| `call(method, params, tier:)` | Sends any Web API method with form fields and returns the raw JSON (`JSON::Any`). |
| `each_page(request) { \|page\| }` | Sends a paginated request once for each page. See [Read all pages](#read-all-pages). |
| `start_stream(request)` | Starts a streamed message. See [AI apps](ai-apps.md#stream-a-message). |

`Client.new` takes these arguments:

| Argument | Default | Use |
| --- | --- | --- |
| `token:` | Required; `nil` is allowed | A `String` or `Auth::Secret`. Without a token, the client sends no `Authorization` header, so a scoped transport can add the credential. See [authentication](authentication.md#direct-tokens-and-the-client). |
| `configuration:` | `https://slack.com/api/` | An `Auth::APIConfiguration` with a different base URI. |
| `transport:` | An HTTP transport | An `Auth::Transport`, for example `Slack::Testing::RecordingTransport` in tests. See [transport settings](authentication.md#transport-settings-and-failures). |
| `retry:` | `nil` (one attempt) | A `RetryPolicy`. See [Retry rate-limited and unsent requests](#retry-rate-limited-and-unsent-requests). |

The library has no global settings and reads no environment variables. Give the token to the client that uses it.

## Typed requests

Each typed request is a value in `Slack::Api`. Create it, then give it to `call`. The request copies its collections when you create it.

| Family | Requests | Guide |
| --- | --- | --- |
| Messages | `ChatPostMessage`, `ChatUpdate`, `ChatPostEphemeral`, `ChatScheduleMessage`, `ChatScheduledMessagesList`, `ChatDeleteScheduledMessage`, `ChatDelete`, `ChatGetPermalink`, `ChatMeMessage`, `ChatUnfurl` | [Block Kit](block-kit.md#messages) |
| Streaming | `ChatStartStream`, `ChatAppendStream`, `ChatStopStream` | [AI apps](ai-apps.md#stream-a-message) |
| Views | `ViewsOpen`, `ViewsPush`, `ViewsUpdate`, `ViewsPublish` | [Block Kit](block-kit.md#modals-and-home) |
| Conversations | `ConversationsList`, `ConversationsInfo`, `ConversationsHistory`, `ConversationsReplies`, `ConversationsMembers`, `ConversationsCreate`, `ConversationsRename`, `ConversationsArchive`, `ConversationsUnarchive`, `ConversationsJoin`, `ConversationsLeave`, `ConversationsInvite`, `ConversationsKick`, `ConversationsSetTopic`, `ConversationsSetPurpose`, `ConversationsMark`, `ConversationsOpen` | [Conversations](#conversations) |
| Users and groups | `UsersInfo`, `UsersLookupByEmail`, `UsersList`, `UsersConversations`, `UsersProfileGet`, `UsersProfileSet`, `UsersGetPresence`, `UsersSetPresence`, `BotsInfo`, `Usergroups*` | [Users and user groups](#users-and-user-groups) |
| Reactions, pins, bookmarks | `ReactionsAdd`, `ReactionsRemove`, `ReactionsGet`, `ReactionsList`, `PinsAdd`, `PinsRemove`, `PinsList`, `BookmarksAdd`, `BookmarksEdit`, `BookmarksList`, `BookmarksRemove` | [Reactions, pins, and bookmarks](#reactions-pins-and-bookmarks) |
| Files | `FileUpload`, `FilesGetUploadURLExternal`, `FilesCompleteUploadExternal`, `FilesInfo`, `FilesDelete`, `FilesRemoteAdd`, `FilesRemoteShare`, `FilesRemoteUpdate`, `FilesRemoteRemove` | [Files](#files) |
| App threads and agents | `AssistantThreadsSetStatus`, `AssistantThreadsSetSuggestedPrompts`, `AssistantThreadsSetTitle`, `AgentsSessionsSetStatus`, `AgentsSessionsRename` | [AI apps](ai-apps.md#app-threads) |
| Workflow steps | `FunctionsCompleteSuccess`, `FunctionsCompleteError` | [Workflow steps](workflows.md) |
| Apps and auth | `AuthTest`, `AuthRevoke`, `AuthTeamsList`, `AppsUninstall`, `AppsManifest*`, `AppsEventAuthorizationsList`, `AppsConnectionsOpen` | [Authentication](authentication.md) |
| Workspace | `TeamInfo`, `EmojiList`, `ApiTest` | This guide |

## Generic call

A method without a typed request is available through the generic call, as with Bolt's `apiCall`. It sends form fields and returns the raw JSON. Strings are sent unchanged, other values are sent as JSON text, and nil values are omitted:

```crystal
dnd = client.call("dnd.info", {user: "U123"})
dnd["snooze_enabled"].as_bool
```

`tier:` selects the local pacing (default `RateLimitTier::Tier2`). Use the tier from the method's reference page. The generic call applies the same error handling and retry policy as a typed request.

## Errors

| Error | Cause | Values |
| --- | --- | --- |
| `Slack::UI::ValidationError` | A request value breaks a documented limit or a library rule. The client raises it before the send. | `issues` |
| `Slack::Api::Error` | Slack answers `ok: false`, or the response is not valid. | `code` (Slack's error name, such as `channel_not_found`), `messages` (`response_metadata.messages`), `details` (the top-level `errors` array, such as the problems of `invalid_manifest`), `http_status` |
| `Slack::Api::RateLimited` | HTTP 429. It is an `Api::Error`. | `retry_after` from the `Retry-After` header |
| `Slack::Auth::ContractError` | The transport failed. `TransportFailure` means that no request bytes left; `UnknownRemoteOutcome` means that Slack can have received the request. | `code` |

The error message never contains the response body, headers, or token.

## Rate limits

The client paces each method locally at its documented [rate limit tier](https://docs.slack.dev/apis/web-api/rate-limits). Pacing waits in the calling fiber and starts no fibers. Local pacing does not guarantee that Slack accepts the call. Without a retry policy, the client makes exactly one attempt.

## Retry rate-limited and unsent requests

Give the client a `Slack::Api::RetryPolicy` to send a request again in two cases:

- HTTP 429. Slack sends `Retry-After` with the number of seconds to wait. The client waits that time in the calling fiber, then sends the same request again. If `Retry-After` is missing or longer than `max_wait`, the client raises `RateLimited` at once.
- `Slack::Auth::ContractError` with `TransportFailure`. The transport proves that no request bytes left, so the client sends again at once.

```crystal
policy = Slack::Api::RetryPolicy.new(max_attempts: 3, max_wait: 30.seconds)
client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"], retry: policy)
client.call(Slack::Api::ChatPostMessage.new(channel: "C123", text: "Daily digest"))
```

`max_attempts` includes the first attempt. After the last attempt, the client raises the last error. Each attempt waits for local pacing.

The client never sends again after `UnknownRemoteOutcome`, HTTP 5xx, or a Slack error such as `internal_error`. In these cases Slack can already have applied the request, and a second `chat.postMessage` posts a second message. Bolt's Node client retries 5xx responses; this library does not, because Slack methods have no idempotency keys. Decide in your application if the request is safe to send again. The [retry example](../examples/retry_policy.cr) shows a wait and a `Retry-After` above `max_wait`.

## Read all pages

List methods return one page at a time. `each_page` sends a paginated request, yields each `Slack::Api::Page`, and sends the request again with the page's `next_cursor`. It stops when Slack returns an empty, null, or missing cursor. Break from the block to stop early:

```crystal
request = Slack::Api::ConversationsList.new(
  types: [Slack::Api::ConversationType::PublicChannel, Slack::Api::ConversationType::PrivateChannel],
  exclude_archived: true, limit: 200)
client.each_page(request) do |page|
  page.model.channels.each { |channel| puts channel.id }
end
```

Paginated requests are `ConversationsList`, `ConversationsHistory`, `ConversationsReplies`, `ConversationsMembers`, `UsersList`, `UsersConversations`, `AuthTeamsList`, `AppsEventAuthorizationsList`, `ChatScheduledMessagesList`, and `ReactionsList`. Each accepts `cursor:` and `limit:`. The client rejects a `limit` outside 1 to 1000 before it sends the request; Slack checks lower method maximums. Slack recommends 100 to 200 items per page.

Each page is one call: local pacing and the client's retry policy apply, and an error such as `RateLimited` raises from the loop. Since 2025-05-29, Slack limits `conversations.history` and `conversations.replies` to one request per minute and 15 items per page for new apps distributed outside the Slack Marketplace. The client does not enforce this limit. See [pagination](https://docs.slack.dev/apis/web-api/pagination) and [rate limits](https://docs.slack.dev/apis/web-api/rate-limits).

## Conversations

`ConversationsInfo` reads one conversation, with optional `include_locale:` and `include_num_members:`. Conversations read as `PublicChannel`, `PrivateChannel` (also group direct messages), or `IMChat`.

Create, rename, archive, and restore channels with `ConversationsCreate`, `ConversationsRename`, `ConversationsArchive`, and `ConversationsUnarchive`. A name has at most 80 characters; Slack checks the allowed characters. Change membership with `ConversationsJoin`, `ConversationsLeave`, `ConversationsInvite` (1 to 1000 user IDs), and `ConversationsKick` (one user). `ConversationsSetTopic` and `ConversationsSetPurpose` accept at most 250 characters, and `ConversationsMark` moves the read cursor. Requests that change a channel return its `Slack::Models::Conversation`:

```crystal
channel = client.call(Slack::Api::ConversationsCreate.new("incident-42", is_private: true))
client.call(Slack::Api::ConversationsInvite.new(channel.id, ["U1", "U2"], force: true))
client.call(Slack::Api::ConversationsSetTopic.new(channel.id, "Checkout errors"))
```

Slack errors raise `Slack::Api::Error`. For example, `name_taken` means the name exists, `not_in_channel` means the caller is not a member, and `channel_not_found` means the ID is wrong or not visible to the token. When one invited user is not valid, Slack invites nobody and raises the first error; `force: true` invites the valid users.

`ConversationsOpen` opens a direct message with one user or a group direct message with two to eight users. It can also resume a conversation by `channel:`. `channel_id` returns the conversation ID. With `return_im: true`, `channel` is the full conversation: an `IMChat`, or a `PrivateChannel` for a group direct message:

```crystal
dm = client.call(Slack::Api::ConversationsOpen.new(users: ["U1"]))
client.call(Slack::Api::ChatPostMessage.new(channel: dm.channel_id, text: "You lead this incident."))
```

Shared channel invitations (`conversations.inviteShared` and related methods) use the generic call.

## Users and user groups

Read people and bots with `UsersInfo`, `UsersLookupByEmail`, `UsersList`, and `BotsInfo`. A `Slack::Models::User` has `id`, `team_id`, `name`, `real_name`, `tz`, the flags `deleted?`, `is_bot?`, `is_admin?`, and `is_owner?`, and a `profile`. Slack omits empty profile fields, and `email` needs the `users:read.email` scope:

```crystal
user = client.call(Slack::Api::UsersLookupByEmail.new("ana@example.test")).user
puts "#{user.profile.display_name} #{user.tz}"
```

`UsersConversations` reads the conversations of a user. `UsersProfileGet`, `UsersGetPresence`, and `UsersSetPresence` read and set the profile and presence. `UsersProfileSet` sets several fields with `profile:`, or one field with `name:` and `value:`; it needs a user token:

```crystal
client.call(Slack::Api::UsersProfileSet.new(profile: {status_text: "Focus time", status_emoji: ":headphones:"}))
```

User groups use `UsergroupsList`, `UsergroupsCreate`, `UsergroupsUpdate`, `UsergroupsEnable`, `UsergroupsDisable`, `UsergroupsUsersList`, and `UsergroupsUsersUpdate`. `UsergroupsUsersUpdate` replaces all members and needs at least one user ID:

```crystal
group = client.call(Slack::Api::UsergroupsCreate.new("On-call", handle: "oncall")).usergroup
client.call(Slack::Api::UsergroupsUsersUpdate.new(group.id, ["U1", "U3"]))
```

`TeamInfo` reads the token's workspace, or another workspace with `team:` or `domain:`. Slack checks name and handle uniqueness, scopes, and admin permissions.

## Reactions, pins, and bookmarks

`ReactionsAdd` and `ReactionsRemove` add and remove an emoji reaction. `ReactionsGet` reads the reactions of one message or file, and `ReactionsList` reads the items that a user reacted to, page by page. Give a message with `channel:` and `timestamp:`, or a file with `file:`. Slack answers `already_reacted` or `no_reaction` when the reaction is already there or is missing:

```crystal
begin
  client.call(Slack::Api::ReactionsAdd.new(channel: "C123", name: "eyes", timestamp: ts))
rescue error : Slack::Api::Error
  raise error unless error.code == "already_reacted"
end
item = client.call(Slack::Api::ReactionsGet.new(channel: "C123", timestamp: ts, full: true))
(item.message.try(&.reactions) || [] of Slack::Models::Reaction).each do |reaction|
  puts "#{reaction.name} #{reaction.count}"
end
```

`PinsAdd`, `PinsRemove`, and `PinsList` pin, unpin, and list the messages of a channel. Slack answers `already_pinned` for a message that is already pinned. `BookmarksAdd`, `BookmarksEdit`, `BookmarksList`, and `BookmarksRemove` manage the link bookmarks of a channel. `BookmarksEdit` sends only the fields that you give:

```crystal
client.call(Slack::Api::PinsAdd.new("C123", ts))
bookmark = client.call(Slack::Api::BookmarksAdd.new("C123", "Runbook", "https://example.com/runbook", emoji: ":books:")).bookmark
client.call(Slack::Api::BookmarksEdit.new("C123", bookmark.id, title: "Queue runbook"))
```

The client rejects an empty reaction name, an empty bookmark title or link, and an edit without changes before it sends. Slack checks emoji names, links, scopes, and pin and bookmark limits.

## Files

Upload files, read and delete them, and share remote files. The token needs `files:write` to upload or delete, `files:read` to read, `remote_files:write` to add, update, or remove remote files, and `remote_files:share` to share them.

### Upload a file

`Slack::Api::FileUpload` runs Slack's three-step upload flow for one file:

1. `files.getUploadURLExternal` returns an upload URL and a file ID.
2. The library sends the bytes with `POST` and `Content-Type: application/octet-stream` to the upload URL.
3. `files.completeUploadExternal` completes the file and shares it when you give a `FileShare`.

```crystal
transport = Slack::Auth::HTTPTransportFactory.new.build(Slack::Auth::TransportOptions.new)
client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"], transport: transport)

upload = Slack::Api::FileUpload.new("release-notes.txt", File.open("release-notes.txt"),
  title: "Release notes",
  share: Slack::Api::FileShare.new(channel_id: "C123", initial_comment: "Release notes for 1.2"))
files = upload.run(client, transport)
files.first.id # => "F123..."
```

`run` takes two values: the client for the two Web API calls and a transport for the byte upload. The upload URL is on a different host (`files.slack.com`) and needs no token, so the byte upload has no `Authorization` header. Give a raw transport, such as the one from `HTTPTransportFactory`. Do not give the scoped transport of `Auth::RequestContext`: it accepts only the API base URI.

Memory limit: the constructor reads the full `IO` (or `Bytes`) into memory one time and keeps it until the value is released. Use this flow only for files that fit in process memory. Streaming uploads are not supported. The caller owns the `IO` and closes it.

Failures stop the flow:

- Invalid values raise `Slack::UI::ValidationError` before any request.
- A Slack error raises `Slack::Api::Error` with Slack's code, such as `file_upload_size_restricted`.
- A byte upload with a status that is not 2xx raises `Slack::Api::Error` with code `http_error` and that `http_status`. The library does not complete the file.
- An upload URL that is not an absolute HTTPS URL raises `Slack::Api::Error` with code `invalid_response`. The library sends no bytes.
- A completion error does not prove that the file is unshared. After `Slack::Auth::ContractError` with `UnknownRemoteOutcome`, or Slack's `internal_error` or `fatal_error`, Slack can have completed or shared the file. Check the file (for example with `FilesInfo`) before you upload it again.

Slack scans uploaded files for malware before it shows them. Large files can take longer to appear. The byte upload makes one attempt. The two Web API calls follow the client's [retry policy](#retry-rate-limited-and-unsent-requests); without one, the client does not retry.

### Share options

`FileShare` holds the sharing fields of `files.completeUploadExternal`:

| Field | Rule |
| --- | --- |
| `channel_id` or `channels` | One or the other (library policy). Without both, the file stays private. `channels` holds at most 100 IDs. |
| `thread_ts` | Needs exactly one channel. Use the parent message timestamp. |
| `initial_comment` or `blocks` | One or the other. Slack ignores `blocks` when `initial_comment` is present, so the library rejects both. `blocks` takes a `UI::Message`; only its blocks are sent. |
| `username`, `icon_url` or `icon_emoji` | Need the `chat:write.customize` scope. Slack uses `icon_emoji` over `icon_url`, so the library rejects both. |

To complete files that you uploaded yourself, send `FilesCompleteUploadExternal` with `FileReference` values:

```crystal
client.call(Slack::Api::FilesCompleteUploadExternal.new(
  [Slack::Api::FileReference.new("F123", title: "Report")],
  Slack::Api::FileShare.new(channels: ["C123", "C456"])))
```

### Read and delete files

```crystal
file = client.call(Slack::Api::FilesInfo.new("F123")).file
file.mimetype # => "text/plain"
client.call(Slack::Api::FilesDelete.new("F123"))
```

`Slack::Models::File` reads `id`, `name`, `title`, `mimetype`, `filetype`, `size`, `url_private`, `permalink`, `user`, `created`, and `shares` (raw JSON). Only `id` is always present. `FilesInfo` does not read file comments.

### Remote files

A remote file points to a document in another service. Slack does not let apps put a File block in a message directly. Add the remote file, then share it:

```crystal
added = client.call(Slack::Api::FilesRemoteAdd.new(external_id: "plan-2026-q4",
  external_url: "https://docs.example.test/plans/2026-q4", title: "Q4 plan")).file

target = Slack::Api::RemoteFileTarget.external_id("plan-2026-q4") # or RemoteFileTarget.file(added.id)
client.call(Slack::Api::FilesRemoteShare.new(target, channels: ["C123"]))
client.call(Slack::Api::FilesRemoteUpdate.new(target, title: "Q4 plan v2"))
client.call(Slack::Api::FilesRemoteRemove.new(target))
```

`RemoteFileTarget` selects the file by Slack file ID or by external ID, never both. The `indexable_file_contents` and `preview_image` fields need multipart uploads and are not supported. To show a remote file in a link preview, see [Build a remote file block](block-kit.md#build-a-remote-file-block).

References: [working with files](https://docs.slack.dev/messaging/working-with-files/#uploading-files), [files.getUploadURLExternal](https://docs.slack.dev/reference/methods/files.getUploadURLExternal), [files.completeUploadExternal](https://docs.slack.dev/reference/methods/files.completeUploadExternal), [files.info](https://docs.slack.dev/reference/methods/files.info), [files.delete](https://docs.slack.dev/reference/methods/files.delete), and [files.remote.add](https://docs.slack.dev/reference/methods/files.remote.add).

## Limits of the offline tests

The specs and examples use synthetic tokens and stubbed HTTP. They do not prove that Slack accepts a request, that the token has the correct scopes, the live rate limit, or when a scanned file appears.

## Examples

| Example | Shows |
| --- | --- |
| [`web_api.cr`](../examples/web_api.cr) | Typed calls, the generic call, and Slack error codes |
| [`retry_policy.cr`](../examples/retry_policy.cr) | A post sent again after HTTP 429, and a `Retry-After` above `max_wait` |
| [`thread_history.cr`](../examples/thread_history.cr) | Channel history and thread replies across cursor pages |
| [`user_group.cr`](../examples/user_group.cr) | Workspace members read into an on-call user group |
| [`incident_channel.cr`](../examples/incident_channel.cr) | An incident channel created, staffed, and archived |
| [`incident_triage.cr`](../examples/incident_triage.cr) | An incident message acknowledged with a reaction, a pin, and a runbook bookmark |
| [`file_upload.cr`](../examples/file_upload.cr) | A file upload and a remote file share |
| [`app_manifest.cr`](../examples/app_manifest.cr) | An app manifest validated, fixed, created, and exported |
