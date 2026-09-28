require "../../spec_helper"

module CardCarouselSpec
  alias UI = Slack::UI::Checked

  # Written from Slack's Slack icon object reference, in its documented order.
  SLACK_ICON_NAMES = %w[
    archive book bookmark bot bug calendar call caret-left caret-right check
    clipboard code comment compass copy cube download edit email eye-closed
    eye-open file flag folder gear globe heart help image info key lightbulb
    link map mobile new-window pin plus refine refresh rocket save screen
    share sparkle star star-filled tag thumbs-down thumbs-up trash upload user
    warning
  ]

  def self.button(text : String, action_id : String) : UI::BlockElements::Button
    UI::BlockElements::Button.new(text: UI.plain(text), action_id: action_id)
  end

  def self.image(alt_text : String) : UI::BlockElements::Image
    UI::BlockElements::Image.new(alt_text: alt_text, image_url: "https://example.com/image.png")
  end

  def self.issues(error : UI::ValidationError) : Array(Tuple(String, String))
    error.issues.map { |issue| {issue.code, issue.path} }
  end

  describe UI::Blocks::Carousel do
    it "serializes cards with every field, both icon kinds, and a plain button array" do
      mdr = UI::Blocks::Card.new(
        block_id: "department.mdr",
        icon: UI::BlockElements::Image.new(alt_text: "MDR badge", image_url: "https://example.com/icons/mdr.png"),
        title: UI::CompositionObjects::Mrkdwn.new("*MDR*", verbatim: false),
        subtitle: UI.plain("Refining data files"),
        hero_image: UI::BlockElements::Image.new(alt_text: "The MDR office", image_url: "https://example.com/heroes/mdr.png"),
        body: UI::CompositionObjects::Mrkdwn.new("Blue badge required to gain access."),
        subtext: UI::CompositionObjects::PlainText.new("Floor 3", emoji: true),
        actions: {
          UI::BlockElements::Button.new(text: UI.plain("Decline"), action_id: "visit.decline", value: "mdr", style: UI::BlockElements::ButtonStyle::Danger),
          UI::BlockElements::Button.new(text: UI.plain("Map"), action_id: "visit.map", url: "https://example.com/map/mdr"),
          UI::BlockElements::Button.new(text: UI.plain("Visit"), action_id: "visit.request", value: "mdr", style: UI::BlockElements::ButtonStyle::Primary),
        }
      )
      wellness = UI::Blocks::Card.new(
        block_id: "department.wellness",
        icon: UI::CompositionObjects::SlackIcon.new(:heart),
        title: UI.plain("Wellness Center"),
        body: UI.plain("Please take a seat in the waiting room until called.")
      )
      message = UI.message(fallback_text: "Departments open for visits") do |builder|
        builder.carousel({mdr, wellness}, block_id: "departments")
        builder.add(UI::Blocks::Card.new(hero_image: UI::BlockElements::Image.new(alt_text: "Break room", slack_file: UI::CompositionObjects::SlackFile.new(id: "F-SYNTHETIC"))))
      end

      JSON.parse(message.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/card_carousel_message.json"))
    end

    it "places a carousel on Home and a card in both modal kinds" do
      card = UI::Blocks::Card.new(title: UI.plain("Onboarding"), actions: {button("Start", "onboarding.start")})
      home = UI.home(&.carousel({card}))
      display = UI::DisplayModal.new(title: UI.plain("Card"), blocks: {card})
      form = UI.form_modal(title: UI.plain("Card"), submit: UI.plain("Save"), &.add(card))

      expected_card = <<-JSON
        {"type":"card","title":{"type":"plain_text","text":"Onboarding"},
         "actions":[{"type":"button","text":{"type":"plain_text","text":"Start"},"action_id":"onboarding.start"}]}
        JSON
      JSON.parse(home.to_json)["blocks"].should eq JSON.parse(%([{"type":"carousel","elements":[#{expected_card}]}]))
      JSON.parse(display.to_json)["blocks"].should eq JSON.parse("[#{expected_card}]")
      JSON.parse(form.to_json)["blocks"].should eq JSON.parse("[#{expected_card}]")
    end

    it "sends every documented Slack icon name" do
      UI::CompositionObjects::SlackIconName.values.map(&.wire_value).should eq SLACK_ICON_NAMES
      JSON.parse(UI::CompositionObjects::SlackIcon.new(:caret_left).to_json).should eq JSON.parse(%({"type":"icon","name":"caret-left"}))
    end

    it "rejects an unnamed Slack icon value" do
      error = expect_raises(UI::ValidationError) { UI::CompositionObjects::SlackIcon.new(UI::CompositionObjects::SlackIconName.new(99)) }
      issues(error).should eq [{"slack_icon.name.invalid", "name"}]
    end

    it "owns copies of its cards and each card's buttons" do
      buttons = [button("One", "one")]
      card = UI::Blocks::Card.new(actions: buttons)
      cards = [card]
      carousel = UI::Blocks::Carousel.new(elements: cards)
      buttons << button("Two", "two")
      cards << card
      card.actions.try(&.clear)
      carousel.elements.clear

      JSON.parse(carousel.to_json).should eq JSON.parse(<<-JSON)
        {"type":"carousel","elements":[{"type":"card",
          "actions":[{"type":"button","text":{"type":"plain_text","text":"One"},"action_id":"one"}]}]}
        JSON
    end

    it "accepts Slack's documented maximums" do
      card = UI::Blocks::Card.new(
        title: UI.plain("t" * 150), subtitle: UI.plain("s" * 150),
        body: UI.plain("b" * 200), subtext: UI.plain("x" * 200),
        hero_image: image("h" * 2000), icon: image("i" * 2000),
        actions: {button("1", "one"), button("2", "two"), button("3", "three")},
        block_id: "界" * 255
      )
      carousel = UI::Blocks::Carousel.new(elements: Array.new(10) { |index| UI::Blocks::Card.new(title: UI.plain("Card #{index}")) }, block_id: "界" * 255)

      card.block_id.should eq "界" * 255
      carousel.elements.size.should eq 10
    end

    it "rejects card fields beyond Slack's limits" do
      error = expect_raises(UI::ValidationError) do
        UI::Blocks::Card.new(
          title: UI.plain("t" * 151), subtitle: UI::CompositionObjects::Mrkdwn.new("s" * 151),
          body: UI.plain("b" * 201), subtext: UI.plain("x" * 201),
          hero_image: image("h" * 2001), icon: image("i" * 2001),
          actions: {button("1", "one"), button("2", "two"), button("3", "three"), button("4", "one")},
          block_id: "界" * 256
        )
      end
      issues(error).should eq [
        {"card.hero_image.alt_text.too_long", "hero_image.alt_text"},
        {"card.icon.alt_text.too_long", "icon.alt_text"},
        {"card.title.too_long", "title.text"},
        {"card.subtitle.too_long", "subtitle.text"},
        {"card.body.too_long", "body.text"},
        {"card.subtext.too_long", "subtext.text"},
        {"card.actions.too_many", "actions"},
        {"card.action_id.duplicate", "actions[3].action_id"},
        {"card.block_id.too_long", "block_id"},
      ]
    end

    it "requires a hero image, title, actions, or body on each card" do
      error = expect_raises(UI::ValidationError) do
        UI::Blocks::Card.new(subtitle: UI.plain("Only a subtitle"), subtext: UI.plain("And subtext"), icon: UI::CompositionObjects::SlackIcon.new(:info))
      end
      issues(error).should eq [{"card.content.missing", ""}]

      error = expect_raises(UI::ValidationError) { UI::Blocks::Card.new(title: UI.plain("Empty actions"), actions: [] of UI::BlockElements::Button) }
      issues(error).should eq [{"card.actions.empty", "actions"}]
    end

    it "rejects empty, oversized, and duplicate-ID carousels" do
      error = expect_raises(UI::ValidationError) { UI::Blocks::Carousel.new(elements: [] of UI::Blocks::Card) }
      issues(error).should eq [{"carousel.elements.empty", "elements"}]

      cards = Array.new(11) { |index| UI::Blocks::Card.new(title: UI.plain("Card"), block_id: "card.#{index == 1 ? 0 : index}") }
      error = expect_raises(UI::ValidationError) { UI::Blocks::Carousel.new(elements: cards, block_id: "界" * 256) }
      issues(error).should eq [
        {"carousel.elements.too_many", "elements"},
        {"carousel.block_id.duplicate", "elements[1].block_id"},
        {"carousel.block_id.too_long", "block_id"},
      ]
    end
  end
end
