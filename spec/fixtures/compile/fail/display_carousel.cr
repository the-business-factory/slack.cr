require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

carousel = UI::Blocks::Carousel.new(elements: {UI::Blocks::Card.new(title: UI.plain("Open"))})
UI::DisplayModal.new(title: UI.plain("Display"), blocks: [carousel, UI::Blocks::Divider.new])
