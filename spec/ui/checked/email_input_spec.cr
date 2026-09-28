require "../../spec_helper"

module EmailInputSpec
  alias UI = Slack::UI::Checked
  alias EmailInput = UI::BlockElements::EmailInput

  describe EmailInput do
    it "serializes the independent email input contract" do
      config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnEnterPressed])
      input = EmailInput.new(action_id: "contact", initial_value: "ops@example.com", dispatch_action_config: config,
        focus_on_load: false, placeholder: UI.plain("Enter an email", emoji: false))
      JSON.parse(input.to_json).should eq JSON.parse(<<-JSON)
        {"type":"email_text_input","action_id":"contact","initial_value":"ops@example.com",
         "dispatch_action_config":{"trigger_actions_on":["on_enter_pressed"]},"focus_on_load":false,
         "placeholder":{"type":"plain_text","text":"Enter an email","emoji":false}}
        JSON
      JSON.parse(EmailInput.new.to_json).should eq JSON.parse(%({"type":"email_text_input"}))
    end

    it "leaves address syntax to Slack and the application" do
      {"", "not an address", "a@b"}.each do |value|
        JSON.parse(EmailInput.new(initial_value: value).to_json)["initial_value"].should eq value
      end
    end

    it "checks action ID and placeholder limits" do
      EmailInput.new(action_id: "界" * 255, placeholder: UI.plain("界" * 150)).validate.should be_empty
      expect_raises(UI::ValidationError) { EmailInput.new(action_id: "界" * 256) }.issues.first.path.should eq "action_id"
      expect_raises(UI::ValidationError) { EmailInput.new(placeholder: UI.plain("界" * 151)) }.issues.first.path.should eq "placeholder.text"
    end
  end

  describe UI::Blocks::ModalInput do
    it "places an email input in a form modal as an Input block with view-wide focus" do
      view = UI.form_modal(title: UI.plain("Contact"), submit: UI.plain("Save")) do |builder|
        builder.input(label: UI.plain("Email Address"), block_id: "input123", optional: true,
          element: EmailInput.new(action_id: "email_text_input-action", placeholder: UI.plain("Enter an email")))
      end
      JSON.parse(view.to_json).should eq JSON.parse(<<-JSON)
        {"type":"modal","title":{"type":"plain_text","text":"Contact"},"submit":{"type":"plain_text","text":"Save"},"blocks":[
         {"type":"input","block_id":"input123","label":{"type":"plain_text","text":"Email Address"},"optional":true,
          "element":{"type":"email_text_input","action_id":"email_text_input-action",
           "placeholder":{"type":"plain_text","text":"Enter an email"}}}]}
        JSON
      error = expect_raises(UI::ValidationError) do
        UI.form_modal(title: UI.plain("Contact"), submit: UI.plain("Save")) do |builder|
          builder.input(label: UI.plain("Email"), element: EmailInput.new(focus_on_load: true))
          builder.input(label: UI.plain("Seats"), element: UI::BlockElements::NumberInput.new(is_decimal_allowed: false, focus_on_load: true))
        end
      end
      error.issues.map(&.path).should eq ["blocks[1].element.focus_on_load"]
    end
  end
end
