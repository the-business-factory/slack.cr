require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI.message(fallback_text: "Seats") do |builder|
  builder.input(label: UI.plain("Seats"), element: UI::BlockElements::NumberInput.new(is_decimal_allowed: false))
end
