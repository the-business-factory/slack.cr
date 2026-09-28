# A frame that carries one event, interaction, or slash command. The app must
# acknowledge every envelope with its `envelope_id`; see `Acknowledgment`.
#
# The envelope keeps the payload bytes, so `#event`, `#interaction`, and
# `#command` decode them with the same rules as the HTTP path. For example,
# `#command` rejects a duplicate routing field.
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
  getter payload : JSON::Any
  # True when the acknowledgment can carry a response payload.
  getter? accepts_response_payload : Bool
  # SDK-sourced (Bolt JS socket-mode client); not on the Slack reference page.
  getter retry_attempt : Int32?
  # SDK-sourced (Bolt JS socket-mode client); not on the Slack reference page.
  getter retry_reason : String?

  @payload_json : String

  def initialize(@envelope_id : String, @type : String, @payload_json : String,
                 @accepts_response_payload : Bool = false,
                 @retry_attempt : Int32? = nil, @retry_reason : String? = nil)
    @payload = JSON.parse(@payload_json)
    @kind = case @type
            when "events_api"     then Kind::EventsApi
            when "interactive"    then Kind::Interactive
            when "slash_commands" then Kind::SlashCommands
            else                       Kind::Unknown
            end
  end

  # Decodes an `events_api` payload. Raises `Slack::Interactions::TypeMismatch`
  # for another kind.
  def event : Slack::VerifiedEvent | Slack::UrlVerification
    require_kind(Kind::EventsApi, "events_api")
    Slack::Events.parse(@payload_json)
  end

  # Decodes an `interactive` payload. Raises `Slack::Interactions::TypeMismatch`
  # for another kind.
  def interaction : Slack::Interaction
    require_kind(Kind::Interactive, "interactive")
    Slack::Interaction.from_json(@payload_json)
  end

  # Decodes a `slash_commands` payload. Raises `Slack::Interactions::TypeMismatch`
  # for another kind.
  def command : Slack::Command
    require_kind(Kind::SlashCommands, "slash_commands")
    Slack::Commands::Parser.from_json_object(@payload_json)
  end

  private def require_kind(expected : Kind, name : String) : Nil
    raise Slack::Interactions::TypeMismatch.new("type", name, @type) unless @kind == expected
  end
end
