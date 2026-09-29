require "../spec_helper"

module FileInputSnapshotSpec
  alias UI = Slack::UI

  it "sends an owned upload form matching independent request JSON" do
    extensions = ["pdf", "png"]
    builder = UI::FormModalBuilder.new(title: UI.plain("Expenses"), submit: UI.plain("Send"), callback_id: "expense")
    builder.input(label: UI.plain("Receipts"), block_id: "receipts",
      element: UI::BlockElements::FileInput.new(action_id: "files", filetypes: extensions, max_files: 3))
    builder.input(label: UI.plain("Note"), block_id: "note", optional: true,
      element: UI::BlockElements::PlainTextInput.new(action_id: "text"))
    request = Slack::Api::ViewsOpen.new(trigger_id: "synthetic-trigger",
      view: builder.build)
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
    JSON.parse(request.to_json).should eq expected
  end
end
