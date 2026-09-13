require "../../../../src/slack/ui"

divider = Slack::UI::Checked::Blocks::Divider.new
Slack::UI::Checked::Blocks::Actions.new(elements: [divider])
