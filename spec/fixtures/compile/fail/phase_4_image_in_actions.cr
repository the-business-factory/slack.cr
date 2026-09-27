require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Actions.new(elements: [UI::BlockElements::Image.new(image_url: "url", alt_text: "Image")])
