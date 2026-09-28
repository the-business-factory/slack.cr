require "../spec_helper"

describe Slack::Interactions::ModalUpdate do
  it "serializes a complete form acknowledgment with metadata inside the view" do
    view = Slack::UI::Checked.form_modal(
      title: Slack::UI::Checked.plain("Review request", emoji: false),
      submit: Slack::UI::Checked.plain("Save"), close: Slack::UI::Checked.plain("Cancel"),
      callback_id: "request.review", private_metadata: "", external_id: "request-42",
      clear_on_close: false, notify_on_close: true, submit_disabled: false
    ) do |builder|
      builder.input(label: Slack::UI::Checked.plain("Reason"), block_id: "request.reason",
        element: Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "reason", multiline: true))
    end
    response = Slack::Interactions::ModalUpdate.new(view)
    # Authored from Slack's response-action and modal contracts, not serialized UI.
    expected = JSON.parse(<<-JSON)
      {"response_action":"update","view":{"type":"modal",
        "title":{"type":"plain_text","text":"Review request","emoji":false},
        "submit":{"type":"plain_text","text":"Save"},"close":{"type":"plain_text","text":"Cancel"},
        "callback_id":"request.review","private_metadata":"","external_id":"request-42",
        "clear_on_close":false,"notify_on_close":true,"submit_disabled":false,
        "blocks":[{"type":"input","block_id":"request.reason","label":{"type":"plain_text","text":"Reason"},
          "element":{"type":"plain_text_input","action_id":"reason","multiline":true}}]}}
      JSON
    JSON.parse(response.to_json).should eq(expected)
  end

  it "supports a display update without a submit button or API envelope fields" do
    view = Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Saved")) do |builder|
      builder.section(Slack::UI::Checked.plain("Request saved."))
    end
    response = Slack::Interactions::ModalUpdate.new(view)
    JSON.parse(response.to_json).should eq(JSON.parse(<<-JSON))
      {"response_action":"update","view":{"type":"modal","title":{"type":"plain_text","text":"Saved"},
        "blocks":[{"type":"section","text":{"type":"plain_text","text":"Request saved."}}]}}
      JSON
  end

  it "owns nested selections and blocks across caller, getter, and struct copies" do
    channels = ["C-ONE", "C-TWO"]
    input = Slack::UI::Checked::Blocks::Input.new(label: Slack::UI::Checked.plain("Channels"), block_id: "channels",
      element: Slack::UI::Checked::BlockElements::MultiChannelsSelect.new(action_id: "destinations", initial_channels: channels))
    blocks = [input]
    view = Slack::UI::Checked::FormModal.new(title: Slack::UI::Checked.plain("Notify"), submit: Slack::UI::Checked.plain("Save"), blocks: blocks)
    response = Slack::Interactions::ModalUpdate.new(view)
    copy = response

    channels.clear
    blocks.clear
    view.blocks.clear
    exposed = response.view.blocks.first.should be_a(Slack::UI::Checked::Blocks::Input)
    control = exposed.element.should be_a(Slack::UI::Checked::BlockElements::MultiChannelsSelect)
    control.initial_channels.should_not(be_nil).clear
    copy.view.blocks.clear

    expected = JSON.parse(<<-JSON)
      {"response_action":"update","view":{"type":"modal","title":{"type":"plain_text","text":"Notify"},
        "submit":{"type":"plain_text","text":"Save"},"blocks":[{"type":"input","block_id":"channels",
        "label":{"type":"plain_text","text":"Channels"},"element":{"type":"multi_channels_select",
        "action_id":"destinations","initial_channels":["C-ONE","C-TWO"]}}]}}
      JSON
    JSON.parse(response.to_json).should eq(expected)
    JSON.parse(copy.to_json).should eq(expected)
  end

  it "rejects duplicate input block IDs while composing an updated form" do
    error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::Interactions::ModalUpdate.new(Slack::UI::Checked.form_modal(
        title: Slack::UI::Checked.plain("Review"), submit: Slack::UI::Checked.plain("Save")
      ) do |builder|
        builder.input(label: Slack::UI::Checked.plain("Reason"), block_id: "request.reason",
          element: Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "reason"))
        builder.input(label: Slack::UI::Checked.plain("Details"), block_id: "request.reason",
          element: Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "details"))
      end)
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq([
      {"modal.block_id.duplicate", "blocks[1].block_id"},
    ])
  end
end
