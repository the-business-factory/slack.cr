require "../spec_helper"

describe "received datetime choices" do
  it "decodes independently authored actions and state as Unix seconds" do
    interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
      {"type":"block_actions","actions":[
       {"type":"datetimepicker","block_id":"schedule","action_id":"start","action_ts":"1710000000.000001","selected_date_time":1628633820,"future":true}],
       "state":{"values":{"schedule":{
        "start":{"type":"datetimepicker","selected_date_time":1628637420},
        "date":{"type":"datepicker","selected_date":"2021-08-10"}}}}}
      JSON
    action = interaction.actions[0].should be_a(Slack::Interactions::DatetimePickerAction)
    action.type.should eq "datetimepicker"
    action.selected_date_time.should eq 1628633820_i64
    action.selected_date_time_presence.present?.should be_true
    action.action_id.should eq "start"
    action.block_id.should eq "schedule"
    action.action_ts.should eq "1710000000.000001"
    state = interaction.state
    value = state.datetime_picker_value?("schedule", "start").should_not be_nil
    value.selected_date_time.should eq 1628637420_i64
    state.datetime_picker_value?("schedule", "missing").should be_nil
    expect_raises(Slack::Interactions::TypeMismatch) { state.datetime_picker_value?("schedule", "date") }.path.should eq %(state.values["schedule"]["date"])
    expect_raises(Slack::Interactions::TypeMismatch) { state.date_picker_value?("schedule", "start") }.path.should eq %(state.values["schedule"]["start"])
  end

  it "preserves absence and cleared null in submissions and actions" do
    { {"", Slack::Interactions::ValuePresence::Absent}, { %q(,"selected_date_time":null), Slack::Interactions::ValuePresence::Null } }.each do |field, presence|
      payload = %({"type":"view_submission","view":{"state":{"values":{"schedule":{"start":{"type":"datetimepicker"#{field}}}}}}})
      submission = Slack::Interaction.from_json(payload).should be_a(Slack::Interactions::ViewSubmission)
      value = submission.state.datetime_picker_value?("schedule", "start").should_not be_nil
      value.selected_date_time.should be_nil
      value.selected_date_time_presence.should eq presence
      actions = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"datetimepicker","block_id":"b","action_id":"a"#{field}}])))
      action = actions[0].should be_a(Slack::Interactions::DatetimePickerAction)
      action.selected_date_time.should be_nil
      action.selected_date_time_presence.should eq presence
    end
  end

  it "rejects non-integer selections and wrong ID types with paths while keeping raw JSON" do
    {"selected_date_time" => %("1628633820"), "action_id" => "42", "block_id" => "[]", "action_ts" => "false"}.each do |field, value|
      raw = JSON.parse(%({"type":"datetimepicker","block_id":"b","action_id":"a"})).as_h
      raw[field] = JSON.parse(value)
      interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
      JSON.parse(interaction.to_json)["actions"].should eq JSON.parse([raw].to_json)
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.actions }.path.should eq "actions[0].#{field}"
    end
    {"1628633820.5", "true", "{}"}.each do |value|
      map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"datetimepicker","selected_date_time":#{value}}}}})))
      expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].selected_date_time)
    end
  end
end
