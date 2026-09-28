require "../spec_helper"

describe Slack::Interactions::ModalPush do
  it "serializes a complete form acknowledgment with owned nested choices" do
    option = Slack::UI::Checked::CompositionObjects::Option.new(text: Slack::UI::Checked.plain("Email"), value: "email")
    options = [option]
    group = Slack::UI::Checked::CompositionObjects::OptionGroup.new(label: Slack::UI::Checked.plain("Delivery"), options: options)
    groups = [group]
    initial = [option]
    control = Slack::UI::Checked::BlockElements::MultiStaticSelect.new(
      action_id: "delivery", option_groups: groups, initial_options: initial, focus_on_load: false)
    builder = Slack::UI::Checked::FormModalBuilder.new(
      title: Slack::UI::Checked.plain("Next step"), submit: Slack::UI::Checked.plain("Save"),
      close: Slack::UI::Checked.plain("Back"), callback_id: "request.delivery", private_metadata: %({"request":42}),
      external_id: "request-42-delivery", clear_on_close: false, notify_on_close: true, submit_disabled: false)
    builder.input(label: Slack::UI::Checked.plain("Delivery"), block_id: "delivery", element: control, optional: false)
    view = builder.build
    response = Slack::Interactions::ModalPush.new(view: view)
    copy = response

    options.clear
    groups.clear
    initial.clear
    group.options.clear
    control.option_groups.should_not(be_nil).first.options.clear
    control.initial_options.should_not(be_nil).clear
    builder.divider
    view.blocks.clear
    copy.view.blocks.clear
    input = response.view.blocks.first.should be_a(Slack::UI::Checked::Blocks::Input)
    nested = input.element.should be_a(Slack::UI::Checked::BlockElements::MultiStaticSelect)
    nested.option_groups.should_not(be_nil).first.options.clear
    nested.initial_options.should_not(be_nil).clear

    # Authored from Slack's acknowledgment contract, independent of serialization.
    expected = JSON.parse(<<-JSON)
      {"response_action":"push","view":{"type":"modal","title":{"type":"plain_text","text":"Next step"},
        "submit":{"type":"plain_text","text":"Save"},"close":{"type":"plain_text","text":"Back"},
        "callback_id":"request.delivery","private_metadata":"{\\"request\\":42}","external_id":"request-42-delivery",
        "clear_on_close":false,"notify_on_close":true,"submit_disabled":false,
        "blocks":[{"type":"input","block_id":"delivery","label":{"type":"plain_text","text":"Delivery"},"optional":false,
          "element":{"type":"multi_static_select","action_id":"delivery","focus_on_load":false,
            "option_groups":[{"label":{"type":"plain_text","text":"Delivery"},"options":[{"text":{"type":"plain_text","text":"Email"},"value":"email"}]}],
            "initial_options":[{"text":{"type":"plain_text","text":"Email"},"value":"email"}]}}]}}
      JSON
    JSON.parse(response.to_json).should eq expected
    JSON.parse(copy.to_json).should eq expected
  end

  it "acknowledges with a display modal and omits optional fields" do
    view = Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Details"), &.divider)
    response = Slack::Interactions::ModalPush.new(view)
    response.to_json.should eq(%q({"response_action":"push","view":{"type":"modal","title":{"type":"plain_text","text":"Details"},"blocks":[{"type":"divider"}]}}))
  end

  it "rejects invalid next-view composition before producing an acknowledgment" do
    error = expect_raises(Slack::UI::Checked::ValidationError) do
      view = Slack::UI::Checked.form_modal(title: Slack::UI::Checked.plain("Details"), submit: Slack::UI::Checked.plain("Save")) do |builder|
        builder.input(label: Slack::UI::Checked.plain("Reason"), block_id: "reason",
          element: Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "text"))
        builder.divider(block_id: "reason")
      end
      Slack::Interactions::ModalPush.new(view).to_json
    end
    error.issues.map(&.code).should contain("modal.block_id.duplicate")
  end
end
