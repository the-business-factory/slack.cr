require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Input.new(label: UI.plain("Label"), element: UI::BlockElements::Image.new(image_url: "url", alt_text: "Image"))
