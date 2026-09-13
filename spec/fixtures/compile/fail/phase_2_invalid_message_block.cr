require "../../../../src/slack/ui"

struct ForbiddenMessageBlock
end

Slack::UI::Checked::Message.new(
  fallback_text: "Compile failure",
  blocks: [ForbiddenMessageBlock.new]
)
