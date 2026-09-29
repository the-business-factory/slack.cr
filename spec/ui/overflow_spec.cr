require "../spec_helper"
require "../support/one_pass"

module OverflowSpec
  alias UI = Slack::UI
  alias Option = UI::CompositionObjects::OverflowOption
  alias Overflow = UI::BlockElements::Overflow

  describe Overflow do
    it "serializes an action and a URL option with confirmation independently of the wire fixture" do
      menu = Overflow.new(action_id: "request.more", options: {
        Option.new(text: UI.plain("Archive", emoji: false), value: "archive"),
        Option.new(text: UI.plain("Details"), value: "details", description: UI.plain("Open request"), url: "https://example.com/requests/42"),
      }, confirm: UI::CompositionObjects::Confirmation.new(
        title: UI.plain("Continue?"), text: UI.mrkdwn("Apply to *request 42*"), confirm: UI.plain("Continue"), deny: UI.plain("Cancel")))
      JSON.parse(menu.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/overflow.json"))
    end

    it "rejects empty, oversized, and ambiguous option lists" do
      expect_raises(UI::ValidationError) { Overflow.new(options: [] of Option) }.issues.first.code.should eq "overflow.options.size"
      options = (1..6).map { |index| Option.new(text: UI.plain("Choice"), value: index.to_s) }
      expect_raises(UI::ValidationError) { Overflow.new(options: options) }.issues.first.code.should eq "overflow.options.size"
      error = expect_raises(UI::ValidationError) { Overflow.new(options: {options[0], options[0]}) }
      error.issues.first.code.should eq "overflow.options.value.duplicate"
      error.issues.first.path.should eq "options[1].value"
      Overflow.new(options: options.first(5)).options.size.should eq 5
    end
    it "fits Section and mixed Actions on each surface and rejects duplicate action IDs" do
      menu = Overflow.new(options: {Option.new(text: UI.plain("Archive"), value: "archive")}, action_id: "more")
      button = UI::BlockElements::Button.new(text: UI.plain("Approve"), action_id: "approve")
      {UI::MessageBuilder.new(fallback_text: "Request"), UI::HomeBuilder.new,
       UI::DisplayModalBuilder.new(title: UI.plain("Request")),
       UI::FormModalBuilder.new(title: UI.plain("Request"), submit: UI.plain("Save"))}.each do |builder|
        builder.section(UI.plain("Request"), accessory: menu)
        builder.actions({button, menu})
        wire = JSON.parse(builder.build.to_json)
        wire["blocks"][0]["accessory"]["type"].should eq "overflow"
        wire["blocks"][1]["elements"].as_a.map(&.["type"].as_s).should eq ["button", "overflow"]
      end
      duplicate = UI::BlockElements::Button.new(text: UI.plain("Other"), action_id: "more")
      error = expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({menu, duplicate}) }
      error.issues.first.code.should eq "actions.action_id.duplicate"
      error.issues.first.path.should eq "elements[1].action_id"
    end
    it "checks character limits while preserving omitted and empty optional fields" do
      option = Option.new(text: UI.plain("界" * 75, emoji: false), value: "界" * 150,
        description: UI.plain("界" * 75), url: "界" * 3000)
      Overflow.new(options: {option}, action_id: "界" * 255).validate.should be_empty
      {
        "text.text"        => -> { Option.new(text: UI.plain("界" * 76), value: "x") },
        "value"            => -> { Option.new(text: UI.plain("X"), value: "界" * 151) },
        "description.text" => -> { Option.new(text: UI.plain("X"), value: "x", description: UI.plain("界" * 76)) },
        "url"              => -> { Option.new(text: UI.plain("X"), value: "x", url: "界" * 3001) },
      }.each do |path, construct|
        expect_raises(UI::ValidationError) { construct.call }.issues.first.path.should eq path
      end
      expect_raises(UI::ValidationError) { Overflow.new(options: {option}, action_id: "界" * 256) }.issues.first.path.should eq "action_id"
      minimal = Overflow.new(options: {Option.new(text: UI.plain("X"), value: "")})
      JSON.parse(minimal.to_json).should eq JSON.parse(%({"type":"overflow","options":[{"text":{"type":"plain_text","text":"X"},"value":""}]}))
      empty = Overflow.new(options: {Option.new(text: UI.plain("X", emoji: false), value: "", url: "")}, action_id: "")
      wire = JSON.parse(empty.to_json)
      wire["action_id"].should eq ""
      wire["options"][0]["url"].should eq ""
      wire["options"][0]["text"]["emoji"].as_bool.should be_false
    end

    it "copies supported yielded options once even when the declared item type includes nil" do
      source = SpecSupport::OnePass.new([Option.new(text: UI.plain("Archive"), value: "archive")])
      menu = Overflow.new(options: source)
      copy = menu
      copy.options.clear
      menu.options.map(&.value).should eq ["archive"]
      source.passes.should eq 1
    end
  end
end
