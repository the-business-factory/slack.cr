# The frame that acknowledges one `Envelope`. Send it within three seconds of
# receipt. It has a `payload` only when one is given.
#
# ```
# ack = Slack::SocketMode::Acknowledgment.new(envelope.envelope_id)
# ack.to_json # => %({"envelope_id":"..."})
# ```
struct Slack::SocketMode::Acknowledgment
  # Response bodies that the HTTP path also returns. Send one only when
  # `Envelope#accepts_response_payload?` is true.
  alias Payload = Slack::Interactions::ModalErrors |
                  Slack::Interactions::ModalPush |
                  Slack::Interactions::ModalUpdate |
                  Slack::Interactions::ModalClear |
                  Slack::Interactions::BlockSuggestionResponse |
                  Slack::Commands::Response

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
