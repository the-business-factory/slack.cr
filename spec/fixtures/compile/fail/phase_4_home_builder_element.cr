require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI.home { |builder| builder.add(UI::BlockElements::Image.new(image_url: "url", alt_text: "Image")) }
