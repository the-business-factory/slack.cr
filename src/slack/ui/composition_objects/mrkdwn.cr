struct Slack::UI::CompositionObjects::Mrkdwn
  include Slack::UI::ValueValidation

  MAX_LENGTH = 3000

  getter text : String
  getter verbatim : Bool?

  def initialize(@text : String, @verbatim : Bool? = nil)
    validate!
  end

  def type : String
    "mrkdwn"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @text.empty?
      issues << Slack::UI::ValidationIssue.new(
        code: "mrkdwn.text.empty",
        path: "text",
        message: "Text must not be empty."
      )
    end
    length_issue(issues, @text, MAX_LENGTH, "mrkdwn.text.too_long", "text", "Text")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "text", @text
      json.field "verbatim", @verbatim unless @verbatim.nil?
    end
  end
end

alias Slack::UI::CompositionObjects::Text = Slack::UI::CompositionObjects::PlainText |
                                            Slack::UI::CompositionObjects::Mrkdwn
