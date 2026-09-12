require "../../spec_helper"

describe Slack::UI::CompositionObjects::DispatchActionConfig do
  it "encodes every supported trigger with explicit wire strings" do
    input = JSON.parse(
      Slack::UI::CompositionObjects::DispatchActionConfig.new(
        Slack::UI::CompositionObjects::DispatchActionConfig::Triggerable::OnInput
      ).to_json
    )
    enter = JSON.parse(
      Slack::UI::CompositionObjects::DispatchActionConfig.new(
        Slack::UI::CompositionObjects::DispatchActionConfig::Triggerable::OnEnter
      ).to_json
    )
    either = JSON.parse(
      Slack::UI::CompositionObjects::DispatchActionConfig.new(
        Slack::UI::CompositionObjects::DispatchActionConfig::Triggerable::OnEither
      ).to_json
    )

    input["trigger_actions_on"].as_a.map(&.as_s).should eq ["on_character_entered"]
    enter["trigger_actions_on"].as_a.map(&.as_s).should eq ["on_enter_pressed"]
    either["trigger_actions_on"].as_a.map(&.as_s).should eq [
      "on_enter_pressed",
      "on_character_entered",
    ]
  end

  it "rejects unnamed trigger values as InvalidUIBlock" do
    expect_raises(Slack::Errors::InvalidUIBlock, "Dispatch action trigger is invalid") do
      Slack::UI::CompositionObjects::DispatchActionConfig.new(
        Slack::UI::CompositionObjects::DispatchActionConfig::Triggerable.new(99)
      )
    end
  end
end
