require "../spec_helper"
require "../support/auth/webmock_transport"

module FileInputSnapshotSpec
  alias UI = Slack::UI::Checked

  it "sends an owned upload form matching independent request JSON" do
    extensions = ["pdf", "png"]
    builder = UI::FormModalBuilder.new(title: UI.plain("Expenses"), submit: UI.plain("Send"), callback_id: "expense")
    builder.input(label: UI.plain("Receipts"), block_id: "receipts",
      element: UI::BlockElements::FileInput.new(action_id: "files", filetypes: extensions, max_files: 3))
    builder.input(label: UI.plain("Note"), block_id: "note", optional: true,
      element: UI::BlockElements::PlainTextInput.new(action_id: "text"))
    request = Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: "synthetic-trigger",
      view: builder.build, transport: AuthSupport::WebMockTransport.new)
    extensions << "exe"
    builder.divider
    # Authored from Slack's file_input, input block and views.open contracts, not from the serializer.
    expected = JSON.parse(<<-JSON)
      {"trigger_id":"synthetic-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Expenses"},
       "submit":{"type":"plain_text","text":"Send"},"callback_id":"expense","blocks":[
        {"type":"input","label":{"type":"plain_text","text":"Receipts"},"block_id":"receipts",
         "element":{"type":"file_input","action_id":"files","filetypes":["pdf","png"],"max_files":3}},
        {"type":"input","label":{"type":"plain_text","text":"Note"},"block_id":"note","optional":true,
         "element":{"type":"plain_text_input","action_id":"text"}}]}}
      JSON
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
