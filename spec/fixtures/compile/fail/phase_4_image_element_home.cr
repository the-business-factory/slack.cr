require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Home.new(blocks: [UI::BlockElements::Image.new(image_url: "url", alt_text: "Image")])
