require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Section.new(text: UI.plain("Text"), accessory: UI::Blocks::Image.new(image_url: "url", alt_text: "Image"))
