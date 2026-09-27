require "../../../../src/slack"

view = Slack::UI::Modal.new(title: Slack::UI::Modal::Title.new("Legacy"), blocks: [] of Slack::TypeAliases::ModalBlock)
Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: "trigger", view: view)
