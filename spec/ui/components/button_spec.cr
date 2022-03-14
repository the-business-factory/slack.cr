require "../../spec_helper"

describe Slack::UI::Components::Button do
  it "render a button with a default confirmation dialog" do
    Slack::UI::Components::Button
      .render(
        action_id: "test",
        button_text: "test",
        confirm: Slack::UI::Components::Button.default_dialog
      )
      .to_pretty_json
      .should eq <<-JSON
      {
        "action_id": "test",
        "confirm": {
          "confirm": {
            "type": "plain_text",
            "text": "Confirm",
            "emoji": false
          },
          "deny": {
            "type": "plain_text",
            "text": "Cancel",
            "emoji": false
          },
          "text": {
            "type": "plain_text",
            "text": "Are you sure?",
            "emoji": false
          },
          "title": {
            "type": "plain_text",
            "text": "Title",
            "emoji": false
          }
        },
        "text": {
          "type": "plain_text",
          "text": "test",
          "emoji": false
        },
        "type": "button"
      }
      JSON
  end
end
