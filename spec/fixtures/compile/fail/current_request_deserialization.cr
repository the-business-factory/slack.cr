require "../../../support/block_kit/prototype"

Slack::Api::ChatPostMessage.from_json(%({"channel":"C123","text":"Text"}))
