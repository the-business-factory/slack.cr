require "../../spec_helper"

private alias CheckedButton = Slack::UI::Checked::BlockElements::Button

describe CheckedButton do
  it "supports a link button without an action ID" do
    button = CheckedButton.new(
      text: Slack::UI::Checked.plain("Open? No, link"),
      url: "https://docs.slack.dev/block-kit"
    )
    payload = JSON.parse(button.to_json)

    payload["type"].as_s.should eq "button"
    payload["url"].as_s.should eq "https://docs.slack.dev/block-kit"
    payload.as_h.has_key?("action_id").should be_false
  end

  it "serializes every current documented field" do
    confirmation = Slack::UI::Checked::CompositionObjects::Confirmation.new(
      title: Slack::UI::Checked.plain("Confirm"),
      text: Slack::UI::Checked.plain("Continue?"),
      confirm: Slack::UI::Checked.plain("Yes"),
      deny: Slack::UI::Checked.plain("No")
    )
    button = CheckedButton.new(
      text: Slack::UI::Checked.plain("Approve", emoji: true),
      action_id: "request.approve",
      url: "https://example.test/requests/42",
      value: "request-42",
      style: Slack::UI::Checked::BlockElements::ButtonStyle::Primary,
      confirm: confirmation,
      accessibility_label: "Approve leave request 42",
      agent_prompt: "Summarize request 42 before approval."
    )
    payload = JSON.parse(button.to_json)

    payload["type"].as_s.should eq "button"
    payload["style"].as_s.should eq "primary"
    payload["confirm"]["title"]["text"].as_s.should eq "Confirm"
    payload["accessibility_label"].as_s.should eq "Approve leave request 42"
    payload["agent_prompt"].as_s.should eq "Summarize request 42 before approval."
  end

  it "accepts string limits and reports every value above its limit" do
    CheckedButton.new(
      text: Slack::UI::Checked.plain("t" * 75),
      action_id: "a" * 255,
      url: "u" * 3000,
      value: "v" * 2000,
      accessibility_label: "l" * 75,
      agent_prompt: "p" * 4000
    )

    cases = {
      "button.text.too_long"                => {76, 1, 1, 1, 1, 1},
      "button.action_id.too_long"           => {1, 256, 1, 1, 1, 1},
      "button.url.too_long"                 => {1, 1, 3001, 1, 1, 1},
      "button.value.too_long"               => {1, 1, 1, 2001, 1, 1},
      "button.accessibility_label.too_long" => {1, 1, 1, 1, 76, 1},
      "button.agent_prompt.too_long"        => {1, 1, 1, 1, 1, 4001},
    }
    cases.each do |code, lengths|
      error = expect_raises(Slack::UI::Checked::ValidationError) do
        CheckedButton.new(
          text: Slack::UI::Checked.plain("t" * lengths[0]),
          action_id: "a" * lengths[1],
          url: "u" * lengths[2],
          value: "v" * lengths[3],
          accessibility_label: "l" * lengths[4],
          agent_prompt: "p" * lengths[5]
        )
      end
      error.issues.map(&.code).should contain(code)
    end
  end

  it "reports unnamed styles as structured validation issues" do
    error = expect_raises(Slack::UI::Checked::ValidationError) do
      CheckedButton.new(
        text: Slack::UI::Checked.plain("Invalid"),
        style: Slack::UI::Checked::BlockElements::ButtonStyle.new(99)
      )
    end

    error.issues.map(&.code).should eq ["button.style.invalid"]
    error.issues.map(&.path).should eq ["style"]
  end
end
