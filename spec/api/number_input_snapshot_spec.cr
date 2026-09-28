require "../spec_helper"
require "../support/auth/webmock_transport"

module NumberInputSnapshotSpec
  alias UI = Slack::UI::Checked

  it "sends an owned number form matching independent request JSON" do
    config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnCharacterEntered])
    seats = UI::BlockElements::NumberInput.new(is_decimal_allowed: false, action_id: "seats", initial_value: "2",
      min_value: "1", max_value: "12", dispatch_action_config: config, focus_on_load: true)
    budget = UI::BlockElements::NumberInput.new(is_decimal_allowed: true, action_id: "budget", placeholder: UI.plain("0.00"))
    builder = UI::FormModalBuilder.new(title: UI.plain("Booking"), submit: UI.plain("Book"), callback_id: "booking")
    builder.input(label: UI.plain("Seats"), block_id: "seats", element: seats, dispatch_action: true)
    builder.input(label: UI.plain("Budget"), block_id: "budget", element: budget, optional: true)
    view = builder.build
    request = Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: "synthetic-trigger",
      view: view, transport: AuthSupport::WebMockTransport.new)
    builder.divider
    view.blocks.clear
    # Authored from Slack's number input, Input block, and views.open contracts, not from the serializer.
    expected = JSON.parse(<<-JSON)
      {"trigger_id":"synthetic-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Booking"},
       "submit":{"type":"plain_text","text":"Book"},"callback_id":"booking","blocks":[
        {"type":"input","label":{"type":"plain_text","text":"Seats"},"block_id":"seats","dispatch_action":true,
         "element":{"type":"number_input","is_decimal_allowed":false,"action_id":"seats","initial_value":"2",
          "min_value":"1","max_value":"12","dispatch_action_config":{"trigger_actions_on":["on_character_entered"]},"focus_on_load":true}},
        {"type":"input","label":{"type":"plain_text","text":"Budget"},"block_id":"budget","optional":true,
         "element":{"type":"number_input","is_decimal_allowed":true,"action_id":"budget","placeholder":{"type":"plain_text","text":"0.00"}}}]}}
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
