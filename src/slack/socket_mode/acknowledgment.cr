require "./response_payload"

# The frame that acknowledges one `Envelope`. Send it within three seconds of
# receipt. It has a `payload` only when one is given.
#
# ```
# ack = Slack::SocketMode::Acknowledgment.new(envelope.envelope_id)
# ack.to_json # => %({"envelope_id":"..."})
# ```
struct Slack::SocketMode::Acknowledgment
  # A response body, such as a `Slack::Commands::Response`. Send one only when
  # `Envelope#accepts_response_payload?` is true.
  alias Payload = ResponsePayload

  getter envelope_id : String
  getter payload : Payload?

  def initialize(@envelope_id : String, @payload : Payload? = nil)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "envelope_id", @envelope_id
      if payload = @payload
        json.field("payload") { payload.to_json(json) }
      end
    end
  end
end
