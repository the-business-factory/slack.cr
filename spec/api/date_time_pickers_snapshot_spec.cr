require "../spec_helper"

module DateTimePickersSnapshotSpec
  alias UI = Slack::UI

  it "sends an owned scheduling form matching independent request JSON" do
    date = UI::BlockElements::DatePicker.new(action_id: "date", initial_date: "2028-02-29", focus_on_load: true)
    time = UI::BlockElements::TimePicker.new(action_id: "time", initial_time: "09:30", timezone: "America/Chicago", focus_on_load: false)
    builder = UI::FormModalBuilder.new(title: UI.plain("Schedule"), submit: UI.plain("Save"), callback_id: "schedule")
    builder.input(label: UI.plain("Date"), block_id: "schedule.date", element: date)
    builder.input(label: UI.plain("Time"), block_id: "schedule.time", element: time, dispatch_action: false)
    view = builder.build
    request = Slack::Api::ViewsOpen.new(trigger_id: "synthetic-trigger",
      view: view)
    builder.divider
    view.blocks.clear
    # Authored from Slack's picker and views.open contracts, not from the serializer.
    expected = JSON.parse(<<-JSON)
      {"trigger_id":"synthetic-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Schedule"},
       "submit":{"type":"plain_text","text":"Save"},"callback_id":"schedule","blocks":[
        {"type":"input","label":{"type":"plain_text","text":"Date"},"block_id":"schedule.date",
         "element":{"type":"datepicker","action_id":"date","initial_date":"2028-02-29","focus_on_load":true}},
        {"type":"input","label":{"type":"plain_text","text":"Time"},"block_id":"schedule.time","dispatch_action":false,
         "element":{"type":"timepicker","action_id":"time","initial_time":"09:30","timezone":"America/Chicago","focus_on_load":false}}]}}
      JSON
    JSON.parse(request.to_json).should eq expected
  end
end
