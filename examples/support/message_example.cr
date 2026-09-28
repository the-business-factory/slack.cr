require "../../src/slack"

module OfflineMessageExample
  struct RequestSummary
    def initialize(@request_id : String, @requester : String)
    end

    def render : Slack::UI::Blocks::Section
      Slack::UI::Blocks::Section.new(
        text: Slack::UI.mrkdwn("*Request #{@request_id}* from #{@requester}"),
        block_id: "request.summary"
      )
    end
  end

  struct RequestControls
    def initialize(@request_id : String)
    end

    def render_into(builder : Slack::UI::MessageBuilder) : Nil
      approve = Slack::UI::BlockElements::Button.new(
        text: Slack::UI.plain("Approve"),
        action_id: "request.approve",
        value: @request_id,
        style: Slack::UI::BlockElements::ButtonStyle::Primary,
        accessibility_label: "Approve request #{@request_id}"
      )
      builder.actions(elements: [approve], block_id: "request.controls")
    end
  end

  def self.run(output : IO = STDOUT) : Nil
    message = Slack::UI.message(
      fallback_text: "Morgan's request 42 needs approval."
    ) do |builder|
      builder.add(RequestSummary.new("42", "Morgan").render)
      builder.divider
      RequestControls.new("42").render_into(builder)
    end

    output.puts message.to_pretty_json
  end
end
