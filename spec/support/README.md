# Test instructions

Run `shards install` and `crystal spec` from the repository root. The suite uses synthetic credentials and WebMock to reject unstubbed external HTTP. The thirteen `examples/block_kit_*.cr` workflows run in the ordinary spec executable and can also be run directly from a checkout with development dependencies installed.

A few checks use child processes: compiler diagnostics, clean full-library startup defaults, native loopback HTTP behavior, and durable storage or rotation crash tests. Native HTTP uses local sockets and synthetic TLS credentials. Give concurrent Crystal runs separate `CRYSTAL_CACHE_DIR` directories; shared temporary executables can interfere. See [storage test support](storage/README.md) when implementing an installation adapter.
