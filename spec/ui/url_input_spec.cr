require "../../spec_helper"

module UrlInputSpec
  alias UI = Slack::UI::Checked
  alias UrlInput = UI::BlockElements::UrlInput

  describe UrlInput do
    it "serializes the independent URL input contract" do
      config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnEnterPressed])
      input = UrlInput.new(action_id: "link", initial_value: "https://example.com/spec", dispatch_action_config: config,
        focus_on_load: false, placeholder: UI.plain("https://", emoji: false))
      JSON.parse(input.to_json).should eq JSON.parse(<<-JSON)
        {"type":"url_text_input","action_id":"link","initial_value":"https://example.com/spec",
         "dispatch_action_config":{"trigger_actions_on":["on_enter_pressed"]},
         "focus_on_load":false,"placeholder":{"type":"plain_text","text":"https://","emoji":false}}
        JSON
      JSON.parse(UrlInput.new.to_json).should eq JSON.parse(%({"type":"url_text_input"}))
    end

    it "checks action ID and placeholder limits" do
      UrlInput.new(action_id: "界" * 255, placeholder: UI.plain("界" * 150)).validate.should be_empty
      expect_raises(UI::ValidationError) { UrlInput.new(action_id: "界" * 256) }.issues.map(&.path).should eq ["action_id"]
      expect_raises(UI::ValidationError) { UrlInput.new(placeholder: UI.plain("界" * 151)) }.issues.map(&.path).should eq ["placeholder.text"]
    end
  end

  describe "URL input placement" do
    it "places a URL input in a form modal Input block and counts its focus" do
      view = UI.form_modal(title: UI.plain("Link"), submit: UI.plain("Save")) do |builder|
        builder.input(label: UI.plain("Link"), block_id: "link", optional: true, dispatch_action: false,
          element: UrlInput.new(action_id: "url", focus_on_load: true))
      end
      JSON.parse(view.to_json).should eq JSON.parse(<<-JSON)
        {"type":"modal","title":{"type":"plain_text","text":"Link"},"submit":{"type":"plain_text","text":"Save"},"blocks":[
         {"type":"input","label":{"type":"plain_text","text":"Link"},"block_id":"link","optional":true,"dispatch_action":false,
          "element":{"type":"url_text_input","action_id":"url","focus_on_load":true}}]}
        JSON
      error = expect_raises(UI::ValidationError) do
        UI::FormModal.new(title: UI.plain("Link"), submit: UI.plain("Save"), blocks: [
          UI::Blocks::Input.new(label: UI.plain("Note"), element: UI::BlockElements::PlainTextInput.new(focus_on_load: true)),
          UI::Blocks::ModalInput.new(label: UI.plain("Link"), element: UrlInput.new(focus_on_load: true)),
        ] of UI::ModalBlock)
      end
      error.issues.map(&.path).should eq ["blocks[1].element.focus_on_load"]
    end
  end
end
