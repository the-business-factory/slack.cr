require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI.home { |builder| builder.image(image_url: "url", alt_text: "Image", title: UI.mrkdwn("Title")) }
