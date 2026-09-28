# Run with: crystal run examples/socket_mode_protocol.cr
# Synthetic Socket Mode frames; no WebSocket connection or Slack API calls.
require "./support/socket_mode_example"

OfflineSocketModeExample.run.each { |ack| puts "ack: #{ack}" }
