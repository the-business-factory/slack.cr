require "../spec_helper"

describe "received number inputs" do
  it "decodes an independently authored dispatched action and view state as strings" do
    interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
      {"type":"block_actions","actions":[
       {"type":"number_input","block_id":"seats","action_id":"count","action_ts":"1710000000.000001","value":"12","future":true}],
       "view":{"state":{"values":{"seats":{"count":{"type":"number_input","value":"-0.50","future":{}}}}}},
       "state":{"values":{"seats":{"count":{"type":"number_input","value":"12"}}}}}
      JSON
    action = interaction.decoded_actions.first.should be_a(Slack::Interactions::NumberInputAction)
    action.value.should eq "12"
    action.value_presence.present?.should be_true
    action.block_id.should eq "seats"
    action.action_id.should eq "count"
    action.action_ts.should eq "1710000000.000001"
    action.type.should eq "number_input"
    action.raw["future"].as_bool.should be_true
    interaction.state_map.number_input_value?("seats", "count").should_not(be_nil).value.should eq "12"
    view_state = interaction.view.should_not(be_nil).state_map.number_input_value?("seats", "count").should_not be_nil
    view_state.value.should eq "-0.50"
    view_state.raw["future"].as_h.should be_empty
  end

  it "preserves absent, cleared, empty, and non-numeric values without outbound checks" do
    {"", "null", %q(""), %q("not a number")}.each do |value|
      field = value.empty? ? "" : %(,"value":#{value})
      payload = %({"type":"view_submission","view":{"state":{"values":{"seats":{"count":{"type":"number_input"#{field}},"note":{"type":"plain_text_input","value":"x"}}}}}})
      state = Slack::Interaction.from_json(payload).should(be_a(Slack::Interactions::ViewSubmission)).state_map
      number = state.number_input_value?("seats", "count").should_not be_nil
      presence = value.empty? ? Slack::Interactions::ValuePresence::Absent : value == "null" ? Slack::Interactions::ValuePresence::Null : Slack::Interactions::ValuePresence::Present
      number.value_presence.should eq presence
      number.value.should eq(presence.present? ? JSON.parse(value).as_s : nil)
      action = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"number_input","block_id":"b","action_id":"a"#{field}}]))).first
      action.should(be_a(Slack::Interactions::NumberInputAction)).value_presence.should eq presence
      state.number_input_value?("seats", "missing").should be_nil
      expect_raises(Slack::Interactions::TypeMismatch) { state.number_input_value?("seats", "note") }.path.should eq %(view.state.values["seats"]["note"])
    end
  end

  it "rejects wrong JSON types with paths while keeping the raw payload available" do
    {"value" => "12", "action_id" => "false", "block_id" => "[]", "action_ts" => "1"}.each do |field, value|
      raw = JSON.parse(%({"type":"number_input","block_id":"b","action_id":"a"})).as_h
      raw[field] = JSON.parse(value)
      interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
      interaction.actions.should eq JSON.parse([raw].to_json)
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.decoded_actions }.path.should eq "actions[0].#{field}"
    end
    map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"number_input","value":12}}}})))
    expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].value)
  end
end
