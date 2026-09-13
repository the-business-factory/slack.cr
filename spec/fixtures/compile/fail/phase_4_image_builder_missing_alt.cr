require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI.home(&.image(image_url: "url"))
