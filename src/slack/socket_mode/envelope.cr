# A frame that carries one event, interaction, or slash command. The app must
# acknowledge every envelope with its `envelope_id`; see `Acknowledgment`.
#
# The envelope keeps the payload as JSON text and does not decode it. Decode
# it with a `Slack::Decoder`, as `Slack::App::SocketModeReceiver` does:
#
# ```
# decoder = Slack::Decoder.default
# case envelope.kind
# in .events_api?     then decoder.event(envelope.payload_json)
# in .interactive?    then decoder.interaction(envelope.payload_json, :json)
# in .slash_commands? then decoder.command(envelope.payload_json, :json)
# in .unknown?        then nil
# end
# ```
struct Slack::SocketMode::Envelope
  enum Kind
    EventsApi
    Interactive
    SlashCommands
    # A type that Slack does not document; see `#type`. Acknowledge it anyway.
    Unknown
  end

  getter envelope_id : String
  getter kind : Kind
  # The envelope type exactly as Slack sent it.
  getter type : String
  # True when the acknowledgment can carry a response payload.
  getter? accepts_response_payload : Bool
  # SDK-sourced (Bolt JS socket-mode client); not on the Slack reference page.
  getter retry_attempt : Int32?
  # SDK-sourced (Bolt JS socket-mode client); not on the Slack reference page.
  getter retry_reason : String?

  # The payload as JSON text. `Frame.parse` copies it from the frame, so the
  # whitespace and string escapes can differ from the frame bytes.
  getter payload_json : String

  def initialize(@envelope_id : String, @type : String, @payload_json : String,
                 @accepts_response_payload : Bool = false,
                 @retry_attempt : Int32? = nil, @retry_reason : String? = nil)
    @kind = case @type
            when "events_api"     then Kind::EventsApi
            when "interactive"    then Kind::Interactive
            when "slash_commands" then Kind::SlashCommands
            else                       Kind::Unknown
            end
  end

  # Returns `#payload_json` when the envelope is of the *expected* kind.
  # Raises `Slack::Interactions::TypeMismatch` for another kind.
  #
  # ```
  # decoder.command(envelope.payload_json(:slash_commands), :json)
  # ```
  def payload_json(expected : Kind) : String
    return @payload_json if @kind == expected
    raise Slack::Interactions::TypeMismatch.new("type", expected.to_s.underscore, @type)
  end
end
