require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI.form_modal(title: UI.plain("Form"), &.divider)
