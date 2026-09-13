require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::FormModal.new(title: UI.plain("Form"), submit: nil, blocks: [] of UI::ModalBlock)
