require "../../../../src/slack"

alias UI = Slack::UI::Checked

Slack::Api::CheckedViewsPublish.new(token: "synthetic", user_id: "U123", view: UI.display_modal(title: UI.plain("Modal")) { |_builder| })
