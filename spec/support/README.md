# Test instructions

Run `shards install` and `crystal spec` from the repository root. The suite uses synthetic credentials and WebMock to reject unstubbed external HTTP.

Use `Slack::Testing` (`require "../../src/slack/testing"`) when a spec checks the request that the library sends:

- `Slack::Testing::RecordingTransport` records each `Auth::TransportRequest` and answers from queued responses or a block. It raises `Slack::Testing::UnstubbedRequest` when it has no response.
- `Slack::Testing::SignedRequest.build` makes a signed Slack request for `Webhooks::Verifier`.

Use `ApiSupport.client` (`spec/support/api/webmock_client.cr`) when a spec needs WebMock URL or header matching. It uses the one WebMock transport, `OfflineExample::WebMockTransport` in `examples/support/webmock_transport.cr`. The `examples/block_kit_*.cr` workflows run in the ordinary spec executable and can also be run directly from a checkout with development dependencies installed.

A few checks use child processes: compiler diagnostics, clean full-library startup defaults, native loopback HTTP behavior, and durable storage or rotation crash tests. Native HTTP uses local sockets and synthetic TLS credentials. Give concurrent Crystal runs separate `CRYSTAL_CACHE_DIR` directories; shared temporary executables can interfere. See [storage test support](storage/README.md) when implementing an installation adapter.
