require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

value = UI::BlockElements::Image.new(image_url: "url", alt_text: "Image")
value.image_url = "new"
