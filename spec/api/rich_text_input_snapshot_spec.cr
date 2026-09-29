require "../spec_helper"

module RichTextInputSnapshotSpec
  alias UI = Slack::UI
  alias RT = UI::RichText

  it "publishes an owned Home rich text input matching independent request JSON" do
    items = [RT::Section.new(elements: {RT::Text.new("Review "), RT::Channel.new("C-RELEASE")})]
    draft = UI::Blocks::RichText.new(elements: {RT::List.new(RT::ListStyle::Bullet, elements: items)})
    config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnEnterPressed])
    builder = UI::HomeBuilder.new(callback_id: "standup")
    builder.input(label: UI.plain("Today"), block_id: "standup", dispatch_action: true,
      element: UI::BlockElements::RichTextInput.new(action_id: "summary", initial_value: draft,
        dispatch_action_config: config, placeholder: UI.plain("What are you working on?"), max_lines: 12))
    view = builder.build
    request = Slack::Api::ViewsPublish.new(user_id: "U-SYNTHETIC",
      view: view)
    items.clear
    draft.elements.clear
    builder.divider
    view.blocks.clear
    # Authored from Slack's rich text input, rich text, Input block, and views.publish contracts, not from the serializer.
    expected = JSON.parse(<<-JSON)
      {"user_id":"U-SYNTHETIC","view":{"type":"home","callback_id":"standup","blocks":[
        {"type":"input","label":{"type":"plain_text","text":"Today"},"block_id":"standup","dispatch_action":true,
         "element":{"type":"rich_text_input","action_id":"summary",
          "initial_value":{"type":"rich_text","elements":[{"type":"rich_text_list","style":"bullet","elements":[
           {"type":"rich_text_section","elements":[{"type":"text","text":"Review "},{"type":"channel","channel_id":"C-RELEASE"}]}]}]},
          "dispatch_action_config":{"trigger_actions_on":["on_enter_pressed"]},
          "placeholder":{"type":"plain_text","text":"What are you working on?"},"max_lines":12}}]}}
      JSON
    JSON.parse(request.to_json).should eq expected
  end
end
