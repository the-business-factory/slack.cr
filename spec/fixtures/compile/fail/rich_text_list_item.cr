require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked
UI::RichText::List.new(UI::RichText::ListStyle::Bullet, elements: {UI::RichText::Text.new("Loose item")})
