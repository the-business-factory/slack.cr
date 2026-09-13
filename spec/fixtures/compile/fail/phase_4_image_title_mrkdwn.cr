require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Image.new(image_url: "url", alt_text: "Image", title: UI.mrkdwn("Title"))
