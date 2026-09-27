require "../../../../src/slack/ui"

struct ForbiddenBuilderBlock
end

builder = Slack::UI::Checked::MessageBuilder.new(fallback_text: "Compile failure")
builder.add(ForbiddenBuilderBlock.new)
