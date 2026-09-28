require "../../spec_helper"

module RadioButtonsSpec
  alias UI = Slack::UI::Checked
  alias Option = UI::CompositionObjects::RadioOption
  alias RadioButtons = UI::BlockElements::RadioButtons

  describe RadioButtons do
    it "serializes both text formats, one exact initial selection, and confirmation" do
      digest = Option.new(text: UI.mrkdwn("*Digest*", verbatim: false), value: "digest", description: UI.mrkdwn("_Daily_"))
      immediate = Option.new(text: UI.plain("Immediate", emoji: false), value: "immediate", description: UI.plain("Every update"))
      control = RadioButtons.new(options: {digest, immediate}, initial_option: digest, action_id: "delivery",
        focus_on_load: false, confirm: UI::CompositionObjects::Confirmation.new(
        title: UI.plain("Change?"), text: UI.plain("Update delivery"), confirm: UI.plain("Yes"), deny: UI.plain("No")))
      # Independently authored from the documented radio and option fields.
      JSON.parse(control.to_json).should eq JSON.parse(<<-JSON)
        {"type":"radio_buttons","action_id":"delivery","focus_on_load":false,
         "options":[{"text":{"type":"mrkdwn","text":"*Digest*","verbatim":false},"value":"digest","description":{"type":"mrkdwn","text":"_Daily_"}},
                    {"text":{"type":"plain_text","text":"Immediate","emoji":false},"value":"immediate","description":{"type":"plain_text","text":"Every update"}}],
         "initial_option":{"text":{"type":"mrkdwn","text":"*Digest*","verbatim":false},"value":"digest","description":{"type":"mrkdwn","text":"_Daily_"}},
         "confirm":{"title":{"type":"plain_text","text":"Change?"},"text":{"type":"plain_text","text":"Update delivery"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
    end

    it "rejects empty, oversized, duplicate, and mismatched choices" do
      options = (1..11).map { |i| Option.new(text: UI.plain("Choice"), value: i.to_s) }
      RadioButtons.new(options: options.first(10)).validate.should be_empty
      {[] of Option, options}.each do |choices|
        expect_raises(UI::ValidationError) { RadioButtons.new(options: choices) }.issues.first.code.should eq "radio_buttons.options.size"
      end
      expect_raises(UI::ValidationError) { RadioButtons.new(options: {options[0], options[0]}) }.issues.first.path.should eq "options[1].value"
      {
        options[1],
        Option.new(text: UI.mrkdwn("Choice"), value: "1"),
        Option.new(text: UI.plain("Choice", emoji: false), value: "1"),
        Option.new(text: UI.plain("Choice"), value: "1", description: UI.plain("Different")),
      }.each do |initial|
        expect_raises(UI::ValidationError) { RadioButtons.new(options: {options[0]}, initial_option: initial) }.issues.first.path.should eq "initial_option"
      end
    end

    it "checks character limits and preserves omitted and explicit false fields" do
      option = Option.new(text: UI.mrkdwn("界" * 75), value: "界" * 150, description: UI.plain("界" * 75))
      RadioButtons.new(options: {option}, action_id: "界" * 255).validate.should be_empty
      {
        "text.text"        => -> { Option.new(text: UI.mrkdwn("界" * 76), value: "x") },
        "value"            => -> { Option.new(text: UI.plain("X"), value: "界" * 151) },
        "description.text" => -> { Option.new(text: UI.plain("X"), value: "x", description: UI.mrkdwn("界" * 76)) },
      }.each do |path, construct|
        expect_raises(UI::ValidationError) { construct.call }.issues.first.path.should eq path
      end
      expect_raises(UI::ValidationError) { RadioButtons.new(options: {option}, action_id: "界" * 256) }.issues.first.path.should eq "action_id"
      simple = Option.new(text: UI.plain("X"), value: "")
      JSON.parse(RadioButtons.new(options: {simple}).to_json).should eq JSON.parse(%({"type":"radio_buttons","options":[{"text":{"type":"plain_text","text":"X"},"value":""}]}))
      explicit = RadioButtons.new(options: {simple}, initial_option: nil, action_id: "", focus_on_load: false)
      JSON.parse(explicit.to_json).should eq JSON.parse(%({"type":"radio_buttons","options":[{"text":{"type":"plain_text","text":"X"},"value":""}],"action_id":"","focus_on_load":false}))
    end
    it "fits Section and mixed Actions on each surface and Input on form surfaces" do
      control = RadioButtons.new(options: {Option.new(text: UI.plain("Digest"), value: "digest")}, action_id: "notifications")
      button = UI::BlockElements::Button.new(text: UI.plain("Save"), action_id: "save")
      {UI::MessageBuilder.new(fallback_text: "Preferences"), UI::HomeBuilder.new,
       UI::DisplayModalBuilder.new(title: UI.plain("Preferences")),
       UI::FormModalBuilder.new(title: UI.plain("Preferences"), submit: UI.plain("Save"))}.each do |builder|
        builder.section(UI.plain("Preferences"), accessory: control)
        builder.actions({button, control})
        wire = JSON.parse(builder.build.to_json)
        wire["blocks"][0]["accessory"]["type"].should eq "radio_buttons"
        wire["blocks"][1]["elements"].as_a.map(&.["type"].as_s).should eq ["button", "radio_buttons"]
      end
      {UI::MessageBuilder.new(fallback_text: "Preferences"), UI::HomeBuilder.new,
       UI::FormModalBuilder.new(title: UI.plain("Preferences"), submit: UI.plain("Save"))}.each do |builder|
        builder.input(label: UI.plain("Notify me"), element: control, optional: true, dispatch_action: true)
        wire = JSON.parse(builder.build.to_json)
        wire["blocks"][0]["element"]["type"].should eq "radio_buttons"
        wire["blocks"][0]["dispatch_action"].as_bool.should be_true
      end
      duplicate = UI::BlockElements::Button.new(text: UI.plain("Other"), action_id: "notifications")
      expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({control, duplicate}) }.issues.first.path.should eq "elements[1].action_id"
    end

    it "counts radio focus with existing inputs across Section, Actions, and Input" do
      control = RadioButtons.new(options: {Option.new(text: UI.plain("Digest"), value: "digest")}, focus_on_load: true)
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
