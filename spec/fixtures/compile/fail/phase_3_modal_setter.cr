require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::FormModal.new(title: UI.plain("Form"), submit: UI.plain("Send"), blocks: [] of UI::ModalBlock).submit = nil
