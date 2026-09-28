require "../../../../src/slack/ui"

alias UI = Slack::UI

alert = UI::Blocks::Alert.new(UI.plain("Deploy failed."), level: UI::Blocks::AlertLevel::Error)
UI::Message.new(fallback_text: "Deploy failed.", blocks: [alert, UI::Blocks::Divider.new])
