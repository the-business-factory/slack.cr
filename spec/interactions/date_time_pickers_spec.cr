require "../spec_helper"

describe "received date and time choices" do
  it "decodes independently authored actions and state without interpreting instants" do
    interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
      {"type":"block_actions","actions":[
       {"type":"datepicker","block_id":"schedule","action_id":"date","action_ts":"1710000000.000001","selected_date":"2028-02-29","future":false},
       {"type":"timepicker","block_id":"schedule","action_id":"time","selected_time":"23:59","timezone":"America/Chicago"}],
       "state":{"values":{"schedule":{
        "date":{"type":"datepicker","selected_date":"2028-03-01","future":[]},
        "time":{"type":"timepicker","selected_time":"00:00","timezone":"America/Chicago"}}}}}
      JSON
    date = interaction.decoded_actions[0].should be_a(Slack::Interactions::DatePickerAction)
    date.selected_date.should eq "2028-02-29"
    date.action_id.should eq "date"
    date.block_id.should eq "schedule"
    date.action_ts.should eq "1710000000.000001"
    date.raw["future"].as_bool.should be_false
    time = interaction.decoded_actions[1].should be_a(Slack::Interactions::TimePickerAction)
    time.selected_time.should eq "23:59"
    time.timezone.should eq "America/Chicago"
    time.timezone_presence.present?.should be_true
    time.action_ts.should be_nil
    state = interaction.state_map
    state.date_picker_value?("schedule", "date").should_not(be_nil).selected_date.should eq "2028-03-01"
    state.time_picker_value?("schedule", "time").should_not(be_nil).selected_time.should eq "00:00"
    state.date_picker_value?("schedule", "date").should_not(be_nil).raw["future"].as_a.should be_empty
    expect_raises(Slack::Interactions::TypeMismatch) { state.date_picker_value?("schedule", "time") }.path.should eq %(state.values["schedule"]["time"])
    expect_raises(Slack::Interactions::TypeMismatch) { state.time_picker_value?("schedule", "date") }.path.should eq %(state.values["schedule"]["date"])
  end

  it "preserves absence, cleared null, empty and malformed-format strings in submissions and actions" do
    {"", "null", %q(""), %q("not a date or time")}.each do |value|
      date_field = value.empty? ? "" : %(,"selected_date":#{value})
      time_fields = value.empty? ? "" : %(,"selected_time":#{value},"timezone":#{value})
      payload = %({"type":"view_submission","view":{"state":{"values":{"schedule":{"date":{"type":"datepicker"#{date_field}},"time":{"type":"timepicker"#{time_fields}}}}}}})
      submission = Slack::Interaction.from_json(payload).should be_a(Slack::Interactions::ViewSubmission)
      state = submission.state_map
      date = state.date_picker_value?("schedule", "date").should_not be_nil
      time = state.time_picker_value?("schedule", "time").should_not be_nil
      presence = value.empty? ? Slack::Interactions::ValuePresence::Absent : value == "null" ? Slack::Interactions::ValuePresence::Null : Slack::Interactions::ValuePresence::Present
      date.selected_date_presence.should eq presence
      time.selected_time_presence.should eq presence
      time.timezone_presence.should eq presence
      expected = presence.present? ? JSON.parse(value).as_s : nil
      date.selected_date.should eq expected
      time.selected_time.should eq expected
      time.timezone.should eq expected
      actions = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"datepicker","block_id":"b","action_id":"d"#{date_field}},{"type":"timepicker","block_id":"b","action_id":"t"#{time_fields}}])))
      actions[0].should(be_a(Slack::Interactions::DatePickerAction)).selected_date_presence.should eq presence
      actions[1].should(be_a(Slack::Interactions::TimePickerAction)).selected_time_presence.should eq presence
      state.date_picker_value?("schedule", "missing").should be_nil
      state.time_picker_value?("missing", "time").should be_nil
      submission.view.should_not(be_nil).state_map["schedule", "time"]?.should eq state["schedule", "time"]?
    end
  end

  it "rejects wrong JSON types with paths while keeping the raw payload available" do
    { {"datepicker", "selected_date", "[]"}, {"timepicker", "selected_time", "42"}, {"timepicker", "timezone", "false"},
     {"datepicker", "action_id", "42"}, {"timepicker", "block_id", "[]"}, {"timepicker", "action_ts", "false"} }.each do |type, field, value|
      raw = JSON.parse(%({"type":"#{type}","block_id":"b","action_id":"a"})).as_h
      raw[field] = JSON.parse(value)
      interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
      interaction.actions.should eq JSON.parse([raw].to_json)
      expect_raises(Slack::Interactions::TypeMismatch) { interaction.decoded_actions }.path.should eq "actions[0].#{field}"
      if field.starts_with?("selected_") || field == "timezone"
        map = Slack::Interactions::StateMap.new(JSON.parse({values: {b: {a: raw}}}.to_json))
        expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].#{field})
      end
    end
  end
end
