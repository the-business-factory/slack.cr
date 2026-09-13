require "../../../../src/slack"

alias UI = Slack::UI::Checked

request = Slack::Api::CheckedViewsPublish.new(token: "synthetic", user_id: "U123", view: UI.home { |_builder| })
request.user_id = "U456"
