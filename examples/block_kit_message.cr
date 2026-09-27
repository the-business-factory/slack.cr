require "../src/slack/ui"

struct RequestSummary
  def initialize(@request_id : String, @requester : String)
  end

  def render : Slack::UI::Checked::Blocks::Section
    Slack::UI::Checked::Blocks::Section.new(
      text: Slack::UI::Checked.mrkdwn("*Request #{@request_id}* from #{@requester}"),
      block_id: "request.summary"
    )
  end
end

struct RequestControls
  def initialize(@request_id : String)
  end

  def render_into(builder : Slack::UI::Checked::MessageBuilder) : Nil
    approve = Slack::UI::Checked::BlockElements::Button.new(
      text: Slack::UI::Checked.plain("Approve"),
      action_id: "request.approve",
      value: @request_id,
      style: Slack::UI::Checked::BlockElements::ButtonStyle::Primary,
      accessibility_label: "Approve request #{@request_id}"
    )
    builder.actions(elements: [approve], block_id: "request.controls")
  end
end

message = Slack::UI::Checked.message(
  fallback_text: "Morgan's request 42 needs approval."
) do |builder|
  builder.add(RequestSummary.new("42", "Morgan").render)
  builder.divider
  RequestControls.new("42").render_into(builder)
end

puts message.to_pretty_json
