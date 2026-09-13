require "../../spec_helper"

describe Slack::UI::BlockElements::Button do
  text = Slack::UI::BlockElements::Button::Text.new("Continue")

  it "encodes every supported style with its explicit wire string" do
    primary = JSON.parse(
      Slack::UI::BlockElements::Button.new(
        action_id: "primary",
        style: Slack::UI::BlockElements::Button::Styles::Primary,
        text: text
      ).to_json
    )
    danger = JSON.parse(
      Slack::UI::BlockElements::Button.new(
        action_id: "danger",
        style: Slack::UI::BlockElements::Button::Styles::Danger,
        text: text
      ).to_json
    )

    primary["style"].as_s.should eq "primary"
    danger["style"].as_s.should eq "danger"
  end

  it "omits an absent style" do
    payload = JSON.parse(
      Slack::UI::BlockElements::Button.new(action_id: "plain", text: text).to_json
    )

    payload.as_h.has_key?("style").should be_false
  end

  it "rejects unnamed style values as InvalidUIBlock" do
    expect_raises(Slack::Errors::InvalidUIBlock, "Button style is invalid") do
      Slack::UI::BlockElements::Button.new(
        action_id: "unknown",
        style: Slack::UI::BlockElements::Button::Styles.new(99),
        text: text
      )
    end
  end
end
