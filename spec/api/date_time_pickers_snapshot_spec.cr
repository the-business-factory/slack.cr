require "../spec_helper"
require "../support/auth/webmock_transport"

module DateTimePickersSnapshotSpec
  alias UI = Slack::UI::Checked

  it "sends an owned scheduling form matching independent request JSON" do
    date = UI::BlockElements::DatePicker.new(action_id: "date", initial_date: "2028-02-29", focus_on_load: true)
    time = UI::BlockElements::TimePicker.new(action_id: "time", initial_time: "09:30", timezone: "America/Chicago", focus_on_load: false)
    builder = UI::FormModalBuilder.new(title: UI.plain("Schedule"), submit: UI.plain("Save"), callback_id: "schedule")
    builder.input(label: UI.plain("Date"), block_id: "schedule.date", element: date)
    builder.input(label: UI.plain("Time"), block_id: "schedule.time", element: time, dispatch_action: false)
    view = builder.build
    request = Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: "synthetic-trigger",
      view: view, transport: AuthSupport::WebMockTransport.new)
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
    sent = 0
    WebMock.stub(:post, "https://slack.com/api/views.open").with(headers: {"Authorization" => "Bearer xoxb-synthetic"}).to_return do |http_request|
      sent += 1
      JSON.parse(http_request.body || fail("Missing body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V-SYNTHETIC","type":"modal"}}))
    end
    request.call.view["id"].should eq "V-SYNTHETIC"
    sent.should eq 1
  end
end
