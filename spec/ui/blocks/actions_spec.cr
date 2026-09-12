require "../../spec_helper"

describe Slack::UI::Blocks::Actions do
  button = ->(index : Int32) do
    Slack::UI::BlockElements::Button.new(
      action_id: "action-#{index}",
      text: Slack::UI::BlockElements::Button::Text.new("Button #{index}")
    )
  end

  it "requires a non-nil, non-empty elements collection" do
    expect_raises(Slack::Errors::InvalidUIBlock, "Actions block elements are required") do
      Slack::UI::Blocks::Actions.new(elements: nil)
    end

    expect_raises(Slack::Errors::InvalidUIBlock, "Actions block must have at least one element") do
      Slack::UI::Blocks::Actions.new(
        elements: [] of Slack::UI::BlockElements::Button
      )
    end
  end

  it "accepts the lower bound and its adjacent value" do
    Slack::UI::Blocks::Actions.new(elements: [button.call(0)])
    Slack::UI::Blocks::Actions.new(elements: [button.call(0), button.call(1)])
  end

  it "accepts 24 and 25 elements and rejects 26" do
    Slack::UI::Blocks::Actions.new(elements: Array.new(24) { |index| button.call(index) })
    Slack::UI::Blocks::Actions.new(elements: Array.new(25) { |index| button.call(index) })

    expect_raises(Slack::Errors::InvalidUIBlock, "Actions block can only have up to 25 elements") do
      Slack::UI::Blocks::Actions.new(
        elements: Array.new(26) { |index| button.call(index) }
      )
    end
  end

  it "serializes a structured collection and optional block_id" do
    payload = JSON.parse(
      Slack::UI::Blocks::Actions.new(
        elements: [button.call(0)],
        block_id: "controls"
      ).to_json
    )

    payload.should eq JSON.parse({
      "type":     "actions",
      "block_id": "controls",
      "elements": [{
        "type":      "button",
        "action_id": "action-0",
        "text":      {
          "type":  "plain_text",
          "text":  "Button 0",
          "emoji": false,
        },
      }],
    }.to_json)
  end
end
