# Run with: crystal run examples/socket_mode_client.cr
# A local WebSocket server stands in for Slack; no Slack connection or credentials.
require "./support/socket_mode_client_example"

OfflineSocketModeClientExample.run.each { |ack| puts "ack: #{ack}" }
