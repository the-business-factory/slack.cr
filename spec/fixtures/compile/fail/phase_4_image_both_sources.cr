require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Image.new(alt_text: "Image", image_url: "url", slack_file: UI::CompositionObjects::SlackFile.new(id: "F123"))
