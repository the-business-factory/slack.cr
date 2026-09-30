# Test instructions

Run `shards install` and `crystal spec` from the repository root. The suite uses synthetic credentials and WebMock to reject unstubbed external HTTP.

Use `Slack::Testing` (`require "../../src/slack/testing"`) when a spec checks the request that the library sends:

- `Slack::Testing::RecordingTransport` records each `Auth::TransportRequest` and answers from queued responses or a block. It raises `Slack::Testing::UnstubbedRequest` when it has no response.
- `Slack::Testing::SignedRequest.build` makes a signed Slack request for `Webhooks::Verifier`.

Use `ApiSupport.client` (`spec/support/api/webmock_client.cr`) when a spec needs WebMock URL or header matching. It uses the one WebMock transport, `OfflineExample::WebMockTransport` in `examples/support/webmock_transport.cr`. The `examples/*.cr` workflows run in the ordinary spec executable and can also be run directly from a checkout with development dependencies installed.

Run the suite through `scripts/spec`, or export `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache` first. The compiler writes every `crystal spec` executable to one file name inside its cache directory, so the shared user cache breaks when two checkouts run specs at the same time. Child compiles started by the suite use the same directory through `SpecSupport::CrystalCache` (`spec/support/crystal_cache.cr`). Do not start two full compiles at once in one checkout.

Three checks start child processes:

- Compiler diagnostics (`spec/block_kit_diagnostics_spec.cr`): one `crystal build --no-codegen` per contract fixture under `spec/fixtures/compile/fail/`, plus the positive control under `pass/`. Add a fixture only for a rule that one parameter type does not show: a diagnostic that the library writes, or a required or exclusive argument pair. Do not add a fixture that only shows that a declared parameter type rejects another type.
- Consumer startup (`spec/entrypoints_spec.cr`): builds `spec/support/entrypoints/startup.cr` with codegen, a program that reaches the library only through `require "slack"` on `CRYSTAL_PATH`.
- Durable storage and rotation across processes (`spec/auth/durable_storage_spec.cr`, `spec/auth/rotation_process_spec.cr`): `spec/support/processes/probe.cr` is built once per run and started as separate processes for lock, crash, and restart behavior.

Native HTTP transport specs run in this executable against loopback sockets with synthetic TLS credentials; WebMock does not intercept the transport. See [storage test support](storage/README.md) when implementing an installation adapter.
