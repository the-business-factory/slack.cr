require "../../../../src/slack"

Slack::Api::CheckedChatPostMessage.from_json(%({"channel":"C123"}))
