require "../../../../src/slack/ui"

alias UI = Slack::UI

UI.message(fallback_text: "Summary") do |builder|
  builder.input(label: UI.plain("Summary"), element: UI::BlockElements::RichTextInput.new(action_id: "summary"))
end
