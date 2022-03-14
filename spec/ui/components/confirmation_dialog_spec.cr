require "../../spec_helper"

describe Slack::UI::Components::ConfirmationDialog do
  it "render a button with a default confirmation dialog" do
    Slack::UI::Components::ConfirmationDialog
      .render(title: "Title", text: "Text", confirm: "Confirm", deny: "Deny")
      .to_pretty_json
      .should eq <<-JSON
      {
        "confirm": {
          "type": "plain_text",
          "text": "Confirm",
          "emoji": false
        },
        "deny": {
          "type": "plain_text",
          "text": "Deny",
          "emoji": false
        },
        "text": {
          "type": "plain_text",
          "text": "Text",
          "emoji": false
        },
        "title": {
          "type": "plain_text",
          "text": "Title",
          "emoji": false
        }
      }
      JSON
  end
end
