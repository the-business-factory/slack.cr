# A positive and a negative feedback button. Slack supports this element only
# in a `Blocks::ContextActions` block.
struct Slack::UI::BlockElements::FeedbackButtons
  include Slack::UI::ValueValidation

  getter positive_button : CompositionObjects::FeedbackButton
  getter negative_button : CompositionObjects::FeedbackButton
  getter action_id : String?

  def initialize(
    *,
    @positive_button : CompositionObjects::FeedbackButton,
    @negative_button : CompositionObjects::FeedbackButton,
    @action_id : String? = nil,
  )
    validate!
  end

  def type : String
    "feedback_buttons"
  end

  def validate : Array(ValidationIssue)
    issues = @positive_button.validate.map(&.at("positive_button"))
    @negative_button.validate.each { |issue| issues << issue.at("negative_button") }
    length_issue(issues, @action_id, 255, "feedback_buttons.action_id.too_long", "action_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "positive_button", @positive_button
      json.field "negative_button", @negative_button
    end
  end
end
