require "../spec_helper"

describe "Home interaction coverage" do
  it "decodes Home buttons, keeps dispatched text actions raw, and reads their typed state" do
    interaction = Slack::Interaction.from_json(File.read("spec/fixtures/block_kit/phase_4_home_action.json"))
    case interaction
    when Slack::Interactions::BlockAction
      interaction.channel.should be_nil
      interaction.view.try(&.["type"].as_s).should eq "home"
      interaction.view.try(&.["future"].as_bool).should be_true
      case button = interaction.decoded_actions.first
      when Slack::Interactions::ButtonAction
        button.action_id.should eq "refresh"
        button.block_id.should eq "controls"
      else
        fail("Expected button action")
      end
      case text = interaction.decoded_actions.last
      when Slack::Interactions::UnknownAction
        text.type.should eq "plain_text_input"
        text.raw["value"].as_s.should eq "Ready"
      else
        fail("Expected raw dispatched text action")
      end
      interaction.state_map.plain_text?("note", "text").should eq "Ready"
      interaction.view.try(&.plain_text?("note", "text")).should eq "Ready"
      interaction.state_map["future", "select"]?.should be_a(Slack::Interactions::UnknownStateValue)
    else
      fail("Expected block action")
    end
  end
end
