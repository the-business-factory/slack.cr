require "../socket_mode/response_payload"

# Outbound JSON body for a slash command. Return it in an HTTP 200
# `application/json` response within three seconds. To acknowledge without a
# message, return an empty HTTP 200 instead.
#
# ```
# Slack::Commands::Response.new(text: "Deploy started.")
# # => {"response_type":"ephemeral","text":"Deploy started."}
# ```
#
# https://docs.slack.dev/interactivity/implementing-slash-commands
struct Slack::Commands::Response
  include Slack::SocketMode::ResponsePayload
  include Slack::UI::ValueValidation

  getter response_type : Slack::Interactions::ResponseType
  getter text : String?
  getter message : Slack::UI::Message?

  def initialize(*, text : String, @response_type : Slack::Interactions::ResponseType = :ephemeral)
    @text = text
    @message = nil
    validate!
  end

  def initialize(*, message : Slack::UI::Message, @response_type : Slack::Interactions::ResponseType = :ephemeral)
    @text = nil
    @message = message
    validate!
  end

  # Nonblank text is library policy: Slack shows nothing useful for it.
  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if (text = @text) && text.blank?
      issues << Slack::UI::ValidationIssue.new("command_response.text.blank", "text", "Text must not be blank.")
    end
    @message.try { |message| issues.concat(message.validate) }
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "response_type", @response_type
      json.field "text", @text if @text
      if message = @message
        json.field "text", message.fallback_text if message.fallback_text
        json.field("blocks") { message.blocks_to_json(json) }
      end
    end
  end
end
