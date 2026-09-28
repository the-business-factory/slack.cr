require "../spec_helper"
require "../support/api/webmock_client"

module DatetimePickerSnapshotSpec
  alias UI = Slack::UI

  it "posts an owned message with datetime pickers matching independent request JSON" do
    start = UI::BlockElements::DatetimePicker.new(action_id: "start", initial_date_time: Time.unix(1628633820), focus_on_load: true)
    builder = UI::MessageBuilder.new(fallback_text: "Pick a start")
    builder.actions({start}, block_id: "meeting")
    builder.input(label: UI.plain("End"), block_id: "meeting.end", element: UI::BlockElements::DatetimePicker.new(action_id: "end"), optional: true)
    message = builder.build
    client = ApiSupport.client("xoxb-synthetic")
    request = Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC",
      message: message)
    builder.divider
    # Authored from Slack's datetime picker and chat.postMessage contracts, not from the serializer.
    expected = JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Pick a start","blocks":[
        {"type":"actions","block_id":"meeting","elements":[
         {"type":"datetimepicker","action_id":"start","initial_date_time":1628633820,"focus_on_load":true}]},
        {"type":"input","label":{"type":"plain_text","text":"End"},"block_id":"meeting.end","optional":true,
         "element":{"type":"datetimepicker","action_id":"end"}}]}
      JSON
    sent = 0
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").with(headers: {"Authorization" => "Bearer xoxb-synthetic"}).to_return do |http_request|
      sent += 1
      JSON.parse(http_request.body || fail("Missing body")).should eq expected
      HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-post-success-section.json"))
    end
    client.call(request)
    sent.should eq 1
  end
end
