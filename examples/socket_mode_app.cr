# Run with: crystal run examples/socket_mode_app.cr
# App listeners receive over Socket Mode from a local WebSocket server; no Slack connection or credentials.
require "./support/socket_mode_app_example"

OfflineSocketModeAppExample.run.each { |ack| puts "ack: #{ack}" }
