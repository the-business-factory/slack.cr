require "../spec_helper"

module MessageCompositionSpec
  module Phase2CompilePass
    alias Section = Slack::UI::Blocks::Section
    alias Divider = Slack::UI::Blocks::Divider
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
        Section.new(text: Slack::UI.mrkdwn("*Summary*"))
      end
    end

    struct Controls
      def render_into(builder : Slack::UI::MessageBuilder) : Nil
        button = Slack::UI::BlockElements::Button.new(
          text: Slack::UI.plain("Approve"),
          action_id: "approve"
        )
        builder.actions(elements: {button})
      end
    end
  end

  describe "message composition" do
    it "executes typed collections and reusable components" do
      section = Phase2CompilePass::Summary.new.render
      divider = Slack::UI::Blocks::Divider.new
      direct = Slack::UI::Message.new(
        fallback_text: "Summary",
        blocks: {section, divider}
      )
      direct.to_json

      builder = Slack::UI::MessageBuilder.new(fallback_text: "Builder")
      builder.add_all([section])
      builder.add_all({section, divider})
      builder.add_all(Phase2CompilePass::AllowedBlocks.new(section))
      Phase2CompilePass::Controls.new.render_into(builder)
      payload = JSON.parse(builder.build.to_json)
      payload["blocks"].as_a.map(&.["type"].as_s).should eq %w[section section divider section actions]
      payload["blocks"][3]["text"]["text"].should eq "*Summary*"
      payload["blocks"][4]["elements"][0]["action_id"].should eq "approve"

      Slack::UI.message_with_slack_generated_fallback do |message|
        2.times { message.add(section) }
      end.to_json
    end
  end
end
