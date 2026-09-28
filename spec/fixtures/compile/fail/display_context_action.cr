require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

trash = UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash, text: UI.plain("Delete"))
UI::DisplayModal.new(title: UI.plain("Display"), blocks: [UI::Blocks::ContextActions.new(elements: {trash}), UI::Blocks::Divider.new])
