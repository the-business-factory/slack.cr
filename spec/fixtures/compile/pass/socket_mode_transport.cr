# Socket Mode frames and acknowledgments without the event, interaction, and
# command implementations.
require "../../../../src/slack/socket_mode/hello"
require "../../../../src/slack/socket_mode/disconnect"
require "../../../../src/slack/socket_mode/unknown_frame"
require "../../../../src/slack/socket_mode/envelope"
require "../../../../src/slack/socket_mode/frame"
require "../../../../src/slack/socket_mode/acknowledgment"

frame = Slack::SocketMode::Frame.parse(%({"type":"events_api","envelope_id":"E-1","payload":{}}))
if frame.is_a?(Slack::SocketMode::Envelope)
  Slack::SocketMode::Acknowledgment.new(frame.envelope_id).to_json
  frame.payload_json(:events_api)
end
