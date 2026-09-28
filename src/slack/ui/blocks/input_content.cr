# :nodoc:
# Shared wire and validation rules for Input blocks. Each block type owns its element union.
module Slack::UI::Blocks::InputContent
  include Slack::UI::ValueValidation

  def type : String
    "input"
  end

  def validate : Array(Slack::UI::ValidationIssue)
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
