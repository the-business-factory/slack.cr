require "../../../../src/slack/ui"

module Phase2CompilePass
  alias Section = Slack::UI::Checked::Blocks::Section
  alias Divider = Slack::UI::Checked::Blocks::Divider
  alias Block = Section | Divider

  class AllowedBlocks
    include Enumerable(Block)

    def initialize(@section : Section)
    end

    # The implementation deliberately yields a narrower type than declared.
    def each(&) : Nil
      yield @section
    end
  end

  struct Summary
    def render : Section
      Section.new(text: Slack::UI::Checked.mrkdwn("*Summary*"))
    end
  end

  struct Controls
    def render_into(builder : Slack::UI::Checked::MessageBuilder) : Nil
      button = Slack::UI::Checked::BlockElements::Button.new(
        text: Slack::UI::Checked.plain("Approve"),
        action_id: "approve"
      )
      builder.actions(elements: {button})
    end
  end
end

section = Phase2CompilePass::Summary.new.render
divider = Slack::UI::Checked::Blocks::Divider.new
direct = Slack::UI::Checked::Message.new(
  fallback_text: "Summary",
  blocks: {section, divider}
)
direct.to_json

builder = Slack::UI::Checked::MessageBuilder.new(fallback_text: "Builder")
builder.add_all([section])
builder.add_all({section, divider})
builder.add_all(Phase2CompilePass::AllowedBlocks.new(section))
Phase2CompilePass::Controls.new.render_into(builder)
builder.build.to_json

Slack::UI::Checked.message_with_slack_generated_fallback do |message|
  2.times { message.add(section) }
end.to_json
