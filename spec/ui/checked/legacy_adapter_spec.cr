require "../../spec_helper"

describe Slack::UI::Checked::LegacyAdapter do
  it "copies every supported legacy Button and confirmation field" do
    confirmation = Slack::UI::CompositionObjects::Confirmation.new(
      title: Slack::UI::CompositionObjects::Confirmation::Title.new("Confirm"),
      text: Slack::UI::CompositionObjects::Confirmation::Text.new(
        "Continue with *request 42*?",
        type: "mrkdwn"
      ),
      confirm: Slack::UI::CompositionObjects::Confirmation::Confirm.new("Yes"),
      deny: Slack::UI::CompositionObjects::Confirmation::Deny.new("No"),
      style: "danger"
    )
    legacy = Slack::UI::BlockElements::Button.new(
      text: Slack::UI::BlockElements::Button::Text.new("Approve"),
      action_id: "request.approve",
      url: "https://example.test/requests/42",
      value: "request-42",
      style: Slack::UI::BlockElements::Button::Styles::Primary,
      confirm: confirmation
    )

    checked = Slack::UI::Checked::LegacyAdapter.button(legacy)
    payload = JSON.parse(checked.to_json)

    payload["action_id"].as_s.should eq "request.approve"
    payload["url"].as_s.should eq "https://example.test/requests/42"
    payload["value"].as_s.should eq "request-42"
    payload["style"].as_s.should eq "primary"
    payload["confirm"]["style"].as_s.should eq "danger"
    payload["confirm"]["text"]["type"].as_s.should eq "mrkdwn"
  end

  it "copies legacy Actions into an immutable checked snapshot" do
    legacy_button = Slack::UI::BlockElements::Button.new(
      text: Slack::UI::BlockElements::Button::Text.new("Approve"),
      action_id: "approve"
    )
    legacy = Slack::UI::Blocks::Actions.new(
      elements: [legacy_button],
      block_id: "controls"
    )
    checked = Slack::UI::Checked::LegacyAdapter.actions(legacy)
    before = checked.to_json

    legacy.elements.clear
    legacy.block_id = "changed"

    checked.to_json.should eq before
  end

  it "rejects unchecked legacy confirmation styles" do
    confirmation = Slack::UI::CompositionObjects::Confirmation.new(
      title: Slack::UI::CompositionObjects::Confirmation::Title.new("Confirm"),
      text: Slack::UI::CompositionObjects::Confirmation::Text.new("Continue?"),
      confirm: Slack::UI::CompositionObjects::Confirmation::Confirm.new("Yes"),
      deny: Slack::UI::CompositionObjects::Confirmation::Deny.new("No"),
      style: "warning"
    )
    legacy = Slack::UI::BlockElements::Button.new(
      text: Slack::UI::BlockElements::Button::Text.new("Approve"),
      action_id: "request.approve",
      confirm: confirmation
    )

    error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::UI::Checked::LegacyAdapter.button(legacy)
    end
    error.issues.map(&.code).should contain("legacy.confirmation.style.invalid")
  end
end
