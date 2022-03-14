require "../../spec_helper"

describe Slack::UI::Components::InputElement do
  it "renders a button with a default confirmation dialog" do
    Slack::UI::Components::InputElement
      .render(
        action_id: "action_id",
        placeholder_text: "placeholder text",
        initial_value: "initial_value",
        label_text: "label_text"
      )
      .to_pretty_json
      .should eq <<-JSON
      {
        "type": "input",
        "element": {
          "type": "plain_text_input",
          "action_id": "action_id",
          "placeholder": {
            "type": "plain_text",
            "text": "placeholder text",
            "emoji": false
          },
          "initial_value": "initial_value",
          "multiline": false,
          "focus_on_load": false
        },
        "label": {
          "type": "plain_text",
          "text": "label_text",
          "emoji": false
        },
        "dispatch_action": false
      }
      JSON
  end
end
