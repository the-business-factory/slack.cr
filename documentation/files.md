# Files

Upload files, read and delete them, and share remote files with `Slack::Api::Client`. The token needs `files:write` to upload or delete, `files:read` to read, `remote_files:write` to add, update, or remove remote files, and `remote_files:share` to share them.

## Upload a file

`Slack::Api::FileUpload` runs Slack's three-step upload flow for one file:

1. `files.getUploadURLExternal` returns an upload URL and a file ID.
2. The library sends the bytes with `POST` and `Content-Type: application/octet-stream` to the upload URL.
3. `files.completeUploadExternal` completes the file and shares it when you give a `FileShare`.

```crystal
require "slack"

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

Slack scans uploaded files for malware before it shows them. Large files can take longer to appear. The client does not retry.

## Share options

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

## Read and delete files

```crystal
file = client.call(Slack::Api::FilesInfo.new("F123")).file
file.mimetype # => "text/plain"
client.call(Slack::Api::FilesDelete.new("F123"))
```

`Slack::Models::File` reads `id`, `name`, `title`, `mimetype`, `filetype`, `size`, `url_private`, `permalink`, `user`, `created`, and `shares` (raw JSON). Only `id` is always present. `FilesInfo` does not read file comments.

## Remote files

A remote file points to a document in another service. Slack does not let apps put a File block in a message directly. Add the remote file, then share it:

```crystal
added = client.call(Slack::Api::FilesRemoteAdd.new(external_id: "plan-2026-q4",
  external_url: "https://docs.example.test/plans/2026-q4", title: "Q4 plan")).file

target = Slack::Api::RemoteFileTarget.external_id("plan-2026-q4") # or RemoteFileTarget.file(added.id)
client.call(Slack::Api::FilesRemoteShare.new(target, channels: ["C123"]))
client.call(Slack::Api::FilesRemoteUpdate.new(target, title: "Q4 plan v2"))
client.call(Slack::Api::FilesRemoteRemove.new(target))
```

`RemoteFileTarget` selects the file by Slack file ID or by external ID, never both. The `indexable_file_contents` and `preview_image` fields need multipart uploads and are not supported.

## Limits of offline tests

The specs and examples use WebMock. They do not prove that Slack accepts an upload, that scopes are correct, or when a scanned file appears.

## Examples

```sh
crystal run examples/file_upload.cr
crystal run examples/block_kit_remote_file.cr
```

References: [working with files](https://docs.slack.dev/messaging/working-with-files/#uploading-files), [files.getUploadURLExternal](https://docs.slack.dev/reference/methods/files.getUploadURLExternal), [files.completeUploadExternal](https://docs.slack.dev/reference/methods/files.completeUploadExternal), [files.info](https://docs.slack.dev/reference/methods/files.info), [files.delete](https://docs.slack.dev/reference/methods/files.delete), and [files.remote.add](https://docs.slack.dev/reference/methods/files.remote.add).
