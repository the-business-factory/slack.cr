require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
multi = UI::BlockElements::MultiStaticSelect.new(options: {option})
UI::DisplayModalBuilder.new(title: UI.plain("Color")).add(UI::Blocks::Input.new(label: UI.plain("Color"), element: multi))
