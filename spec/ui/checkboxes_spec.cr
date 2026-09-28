require "../spec_helper"

module CheckboxesSpec
  alias UI = Slack::UI
  alias Option = UI::CompositionObjects::CheckboxOption
  alias Checkboxes = UI::BlockElements::Checkboxes

  describe Checkboxes do
    it "serializes Markdown choices, exact initial selections, and optional confirmation" do
      digest = Option.new(text: UI.mrkdwn("*Daily digest*", verbatim: false), value: "digest", description: UI.mrkdwn("_Once a day_"))
      alerts = Option.new(text: UI.plain("Alerts", emoji: false), value: "alerts")
      control = Checkboxes.new(options: {digest, alerts}, initial_options: {digest}, action_id: "notifications",
        focus_on_load: false, confirm: UI::CompositionObjects::Confirmation.new(
        title: UI.plain("Change?"), text: UI.plain("Update notifications"), confirm: UI.plain("Yes"), deny: UI.plain("No")))
      JSON.parse(control.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/checkboxes.json"))
    end
    it "rejects empty, oversized, duplicate, and mismatched choices" do
      options = (1..11).map { |i| Option.new(text: UI.plain("Choice"), value: i.to_s) }
      Checkboxes.new(options: options.first(10)).validate.should be_empty
      {[] of Option, options}.each do |choices|
        expect_raises(UI::ValidationError) { Checkboxes.new(options: choices) }.issues.first.code.should eq "checkboxes.options.size"
      end
      expect_raises(UI::ValidationError) { Checkboxes.new(options: {options[0], options[0]}) }.issues.first.path.should eq "options[1].value"
      expect_raises(UI::ValidationError) { Checkboxes.new(options: options.first(1), initial_options: {options[1]}) }.issues.first.code.should eq "checkboxes.initial_option.not_found"
      changed = Option.new(text: UI.mrkdwn("Choice"), value: "1")
      expect_raises(UI::ValidationError) { Checkboxes.new(options: {options[0]}, initial_options: {changed}) }.issues.first.path.should eq "initial_options[0]"
      described = Option.new(text: UI.plain("Choice"), value: "1", description: UI.plain("Different"))
      expect_raises(UI::ValidationError) { Checkboxes.new(options: {options[0]}, initial_options: {described}) }.issues.first.path.should eq "initial_options[0]"
      expect_raises(UI::ValidationError) { Checkboxes.new(options: options, initial_options: {options[0], options[0]}) }.issues.map(&.code).should contain "checkboxes.initial_options.duplicate"
    end

    it "checks character limits and preserves absent, false, and empty fields" do
      option = Option.new(text: UI.mrkdwn("界" * 75), value: "界" * 150, description: UI.plain("界" * 75))
      Checkboxes.new(options: {option}, action_id: "界" * 255).validate.should be_empty
      {
        "text.text"        => -> { Option.new(text: UI.mrkdwn("界" * 76), value: "x") },
        "value"            => -> { Option.new(text: UI.plain("X"), value: "界" * 151) },
        "description.text" => -> { Option.new(text: UI.plain("X"), value: "x", description: UI.mrkdwn("界" * 76)) },
      }.each do |path, construct|
        expect_raises(UI::ValidationError) { construct.call }.issues.first.path.should eq path
      end
      expect_raises(UI::ValidationError) { Checkboxes.new(options: {option}, action_id: "界" * 256) }.issues.first.path.should eq "action_id"
      simple = Option.new(text: UI.plain("X"), value: "")
      JSON.parse(Checkboxes.new(options: {simple}).to_json).should eq JSON.parse(%({"type":"checkboxes","options":[{"text":{"type":"plain_text","text":"X"},"value":""}]}))
      explicit = Checkboxes.new(options: {simple}, initial_options: [] of Option, action_id: "", focus_on_load: false)
      wire = JSON.parse(explicit.to_json)
      wire["initial_options"].as_a.should be_empty
      wire["action_id"].should eq ""
      wire["focus_on_load"].as_bool.should be_false
    end
    it "fits Section and mixed Actions on each surface and Input on form surfaces" do
      control = Checkboxes.new(options: {Option.new(text: UI.plain("Digest"), value: "digest")}, action_id: "notifications")
      button = UI::BlockElements::Button.new(text: UI.plain("Save"), action_id: "save")
      {UI::MessageBuilder.new(fallback_text: "Preferences"), UI::HomeBuilder.new,
       UI::DisplayModalBuilder.new(title: UI.plain("Preferences")),
       UI::FormModalBuilder.new(title: UI.plain("Preferences"), submit: UI.plain("Save"))}.each do |builder|
        builder.section(UI.plain("Preferences"), accessory: control)
        builder.actions({button, control})
        wire = JSON.parse(builder.build.to_json)
        wire["blocks"][0]["accessory"]["type"].should eq "checkboxes"
        wire["blocks"][1]["elements"].as_a.map(&.["type"].as_s).should eq ["button", "checkboxes"]
      end
      {UI::MessageBuilder.new(fallback_text: "Preferences"), UI::HomeBuilder.new,
       UI::FormModalBuilder.new(title: UI.plain("Preferences"), submit: UI.plain("Save"))}.each do |builder|
        builder.input(label: UI.plain("Notify me"), element: control, optional: true, dispatch_action: true)
        wire = JSON.parse(builder.build.to_json)
        wire["blocks"][0]["element"]["type"].should eq "checkboxes"
        wire["blocks"][0]["dispatch_action"].as_bool.should be_true
      end
      duplicate = UI::BlockElements::Button.new(text: UI.plain("Other"), action_id: "notifications")
      expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({control, duplicate}) }.issues.first.path.should eq "elements[1].action_id"
    end

    it "counts checkbox focus with existing inputs across Section, Actions, and Input" do
      control = Checkboxes.new(options: {Option.new(text: UI.plain("Digest"), value: "digest")}, focus_on_load: true)
      {UI::HomeBuilder.new, UI::DisplayModalBuilder.new(title: UI.plain("Preferences")),
       UI::FormModalBuilder.new(title: UI.plain("Preferences"), submit: UI.plain("Save"))}.each do |builder|
        builder.section(UI.plain("Preferences"), accessory: control)
        builder.actions({control})
        expect_raises(UI::ValidationError) { builder.build }.issues.map(&.path).should eq ["blocks[1].elements[0].focus_on_load"]
      end
      home = UI::HomeBuilder.new
      home.input(label: UI.plain("Note"), element: UI::BlockElements::PlainTextInput.new(focus_on_load: true))
      home.input(label: UI.plain("Preferences"), element: control)
      expect_raises(UI::ValidationError) { home.build }.issues.first.path.should eq "blocks[1].element.focus_on_load"
      UI.message(fallback_text: "Preferences") do |builder|
        builder.section(UI.plain("Preferences"), accessory: control)
        builder.actions({control})
      end.validate.should be_empty
    end
  end
end
