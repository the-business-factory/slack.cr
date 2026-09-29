require "../spec_helper"

describe "received email inputs" do
  it "decodes an independently authored dispatched action and view state" do
    interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
      {"type":"block_actions","actions":[
       {"type":"email_text_input","block_id":"contact","action_id":"email","action_ts":"1710000000.000001","value":"ops@example.com","future":true}],
       "view":{"state":{"values":{"contact":{"email":{"type":"email_text_input","value":"lead@example.com","future":{}}}}}},
       "state":{"values":{"contact":{"email":{"type":"email_text_input","value":"ops@example.com"}}}}}
      JSON
    action = interaction.actions.first.should be_a(Slack::Interactions::EmailInputAction)
    action.value.should eq "ops@example.com"
    action.value_presence.present?.should be_true
    action.block_id.should eq "contact"
    action.action_id.should eq "email"
    action.action_ts.should eq "1710000000.000001"
    action.type.should eq "email_text_input"
    interaction.state.email_input_value?("contact", "email").should_not(be_nil).value.should eq "ops@example.com"
    view_state = interaction.view.should_not(be_nil).state.email_input_value?("contact", "email").should_not be_nil
    view_state.value.should eq "lead@example.com"
  end

  it "preserves absent, cleared, empty, and unchecked values" do
    {"", "null", %q(""), %q("not an address")}.each do |value|
      field = value.empty? ? "" : %(,"value":#{value})
      payload = %({"type":"view_submission","view":{"state":{"values":{"contact":{"email":{"type":"email_text_input"#{field}},"seats":{"type":"number_input","value":"2"}}}}}})
      state = Slack::Interaction.from_json(payload).should(be_a(Slack::Interactions::ViewSubmission)).state
      email = state.email_input_value?("contact", "email").should_not be_nil
      presence = value.empty? ? Slack::Interactions::ValuePresence::Absent : value == "null" ? Slack::Interactions::ValuePresence::Null : Slack::Interactions::ValuePresence::Present
      email.value_presence.should eq presence
      email.value.should eq(presence.present? ? JSON.parse(value).as_s : nil)
      action = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"email_text_input","block_id":"b","action_id":"a"#{field}}]))).first
      action.should(be_a(Slack::Interactions::EmailInputAction)).value_presence.should eq presence
      state.email_input_value?("contact", "missing").should be_nil
      expect_raises(Slack::Interactions::TypeMismatch) { state.email_input_value?("contact", "seats") }.path.should eq %(view.state.values["contact"]["seats"])
    end
  end

  it "rejects wrong JSON types with paths while keeping the raw payload available" do
    {"value" => "12", "action_id" => "false", "block_id" => "[]", "action_ts" => "1"}.each do |field, value|
      raw = JSON.parse(%({"type":"email_text_input","block_id":"b","action_id":"a"})).as_h
      raw[field] = JSON.parse(value)
      interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
      JSON.parse(interaction.to_json)["actions"].should eq JSON.parse([raw].to_json)
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.actions }.path.should eq "actions[0].#{field}"
    end
    map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"email_text_input","value":["x"]}}}})))
    expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].value)
  end
end
