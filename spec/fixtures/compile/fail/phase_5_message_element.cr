require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
multi = UI::BlockElements::MultiStaticSelect.new(options: {option})
UI::MessageBuilder.new(fallback_text: "Color").add(multi)
