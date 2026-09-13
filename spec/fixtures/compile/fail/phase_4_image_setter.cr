require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

value = UI::Blocks::Image.new(image_url: "url", alt_text: "Image")
value.alt_text = "New"
