alias Slack::UI::Checked::Blocks::InputElement = Slack::UI::Checked::BlockElements::PlainTextInput

struct Slack::UI::Checked::Blocks::Input
  include Slack::UI::Checked::ValueValidation

  getter label : Slack::UI::Checked::CompositionObjects::PlainText
  getter element : InputElement
  getter block_id : String?
  getter hint : Slack::UI::Checked::CompositionObjects::PlainText?
  getter optional : Bool?
  getter dispatch_action : Bool?

  def initialize(
    @label : Slack::UI::Checked::CompositionObjects::PlainText,
    @element : InputElement,
    @block_id : String? = nil,
    @hint : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @optional : Bool? = nil,
    @dispatch_action : Bool? = nil,
  )
    validate!
  end

  def type : String
    "input"
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = @label.validate.map(&.at("label"))
    length_issue(issues, @label.text, 2000, "input.label.too_long", "label.text")
    length_issue(issues, @block_id, 255, "input.block_id.too_long", "block_id")
    if hint = @hint
      hint.validate.each { |issue| issues << issue.at("hint") }
      length_issue(issues, hint.text, 2000, "input.hint.too_long", "hint.text")
    end
    @element.validate.each { |issue| issues << issue.at("element") }
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "label", @label
      json.field "element", @element
      json.field "block_id", @block_id if @block_id
      json.field "hint", @hint if @hint
      json.field "optional", @optional unless @optional.nil?
      json.field "dispatch_action", @dispatch_action unless @dispatch_action.nil?
    end
  end
end
