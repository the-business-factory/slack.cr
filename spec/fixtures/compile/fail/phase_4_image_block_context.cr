require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Context.new(elements: [UI::Blocks::Image.new(image_url: "url", alt_text: "Image")])
