require "../../spec_helper"

describe Slack::UI::Components::TextSection do
  it "renders a button with a default confirmation dialog" do
    Slack::UI::Components::TextSection
      .render(text: "Text")
      .to_pretty_json
      .should eq <<-JSON
      {
        "type": "section",
        "text": {
          "type": "plain_text",
          "text": "Text",
          "emoji": false
        }
      }
      JSON
  end
end
