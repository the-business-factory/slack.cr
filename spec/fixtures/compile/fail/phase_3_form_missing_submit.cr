require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::FormModal.new(title: UI.plain("Form"), blocks: [] of UI::ModalBlock)
