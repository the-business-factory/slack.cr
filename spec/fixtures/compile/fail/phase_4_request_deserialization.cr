require "../../../../src/slack"

alias UI = Slack::UI::Checked

Slack::Api::CheckedViewsPublish.from_json(%({"user_id":"U123","view":{"type":"home","blocks":[]}}))
