require "../../spec_helper"

module RichTextInputSpec
  alias UI = Slack::UI::Checked
  alias RT = UI::RichText
  alias RichTextInput = UI::BlockElements::RichTextInput

  def self.draft : UI::Blocks::RichText
    UI::Blocks::RichText.new(elements: {RT::Section.new(elements: [
      RT::Text.new("Hello "), RT::User.new("U-AUTHOR"), RT::Text.new("!", style: RT::TextStyle.new(bold: true)),
    ] of RT::Element)})
  end

  describe RichTextInput do
    it "serializes the independent rich text input contract" do
      config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnCharacterEntered])
      input = RichTextInput.new(action_id: "summary", initial_value: draft, dispatch_action_config: config,
        focus_on_load: false, placeholder: UI.plain("Write a summary"), min_lines: 1, max_lines: 100)
      JSON.parse(input.to_json).should eq JSON.parse(<<-JSON)
        {"type":"rich_text_input","action_id":"summary",
         "initial_value":{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[
           {"type":"text","text":"Hello "},{"type":"user","user_id":"U-AUTHOR"},{"type":"text","text":"!","style":{"bold":true}}]}]},
         "dispatch_action_config":{"trigger_actions_on":["on_character_entered"]},"focus_on_load":false,
         "placeholder":{"type":"plain_text","text":"Write a summary"},"min_lines":1,"max_lines":100}
        JSON
      JSON.parse(RichTextInput.new(action_id: "summary").to_json).should eq JSON.parse(%({"type":"rich_text_input","action_id":"summary"}))
    end

    it "checks action ID, placeholder, and visible line limits" do
      RichTextInput.new(action_id: "界" * 255, placeholder: UI.plain("界" * 150)).validate.should be_empty
      {
        {"action_id", "rich_text_input.action_id.empty"}             => -> { RichTextInput.new(action_id: "") },
        {"action_id", "rich_text_input.action_id.too_long"}          => -> { RichTextInput.new(action_id: "界" * 256) },
        {"placeholder.text", "rich_text_input.placeholder.too_long"} => -> { RichTextInput.new(action_id: "a", placeholder: UI.plain("界" * 151)) },
        {"min_lines", "rich_text_input.min_lines.out_of_range"}      => -> { RichTextInput.new(action_id: "a", min_lines: 0) },
        {"max_lines", "rich_text_input.max_lines.out_of_range"}      => -> { RichTextInput.new(action_id: "a", max_lines: 101) },
      }.each do |(path, code), build|
        error = expect_raises(UI::ValidationError) { build.call }
        error.issues.map { |issue| {issue.code, issue.path} }.should eq [{code, path}]
      end
    end
  end

  describe UI::Blocks::ViewInput do
    it "places a rich text input in Home and form modals as an Input block" do
      element = RichTextInput.new(action_id: "summary", focus_on_load: true)
      expected = <<-JSON
        {"type":"input","label":{"type":"plain_text","text":"Summary"},"block_id":"summary","hint":{"type":"plain_text","text":"Mention people"},
         "optional":true,"dispatch_action":false,"element":{"type":"rich_text_input","action_id":"summary","focus_on_load":true}}
        JSON
      home = UI.home do |builder|
        builder.input(label: UI.plain("Summary"), element: element, block_id: "summary", hint: UI.plain("Mention people"),
          optional: true, dispatch_action: false)
      end
      JSON.parse(home.to_json).should eq JSON.parse(%({"type":"home","blocks":[#{expected}]}))
      modal = UI.form_modal(title: UI.plain("Standup"), submit: UI.plain("Post")) do |builder|
        builder.input(label: UI.plain("Summary"), element: element, block_id: "summary", hint: UI.plain("Mention people"),
          optional: true, dispatch_action: false)
      end
      JSON.parse(modal.to_json).should eq JSON.parse(<<-JSON)
        {"type":"modal","title":{"type":"plain_text","text":"Standup"},"submit":{"type":"plain_text","text":"Post"},"blocks":[#{expected}]}
        JSON
    end

    it "applies Input limits, nested element paths, and view-wide focus" do
      element = RichTextInput.new(action_id: "summary", focus_on_load: true)
      expect_raises(UI::ValidationError) { UI::Blocks::ViewInput.new(label: UI.plain("界" * 2001), element: element) }.issues.first.path.should eq "label.text"
      expect_raises(UI::ValidationError) { UI::Blocks::ViewInput.new(label: UI.plain("Summary"), element: element, block_id: "b" * 256) }.issues.first.path.should eq "block_id"
      input = UI::Blocks::ViewInput.new(label: UI.plain("Summary"), element: element, block_id: "summary")
      error = expect_raises(UI::ValidationError) do
        UI::Home.new(blocks: [
          input,
          UI::Blocks::Input.new(label: UI.plain("Note"), element: UI::BlockElements::PlainTextInput.new(focus_on_load: true), block_id: "summary"),
        ] of UI::HomeBlock)
      end
      error.issues.map(&.path).should eq ["blocks[1].block_id", "blocks[1].element.focus_on_load"]
    end
  end
end
