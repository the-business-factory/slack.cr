require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ViewsOpen do
  it "sends a structured form snapshot with external_id inside view" do
    builder = Slack::UI::FormModalBuilder.new(title: Slack::UI.plain("Request"), submit: Slack::UI.plain("Send"), external_id: "request-42")
    builder.input(label: Slack::UI.plain("Reason"), block_id: "reason", element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "text"))
    view = builder.build
    client = ApiSupport.client("xoxb-synthetic")
    request = Slack::Api::ViewsOpen.new(trigger_id: "synthetic-trigger", view: view)
    expected_view = JSON.parse(view.to_json)
    builder.divider
    view.blocks.clear
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/views.open")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic", "Content-Type" => "application/json; charset=utf-8"})
      .to_return do |http_request|
        requests += 1
        body = JSON.parse(http_request.body || fail("Expected JSON body"))
        body.as_h.keys.sort!.should eq ["trigger_id", "view"]
        body["trigger_id"].as_s.should eq "synthetic-trigger"
        body["view"].should eq expected_view
        body["view"]["external_id"].as_s.should eq "request-42"
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V123"}}))
      end
    response = client.call(request)
    response.view["id"].as_s.should eq "V123"
    requests.should eq 1
  end

  it "validates trigger_id before any HTTP" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |_request|
      requests += 1
      HTTP::Client::Response.new(500)
    end
    view = Slack::UI.display_modal(title: Slack::UI.plain("Display")) { |builder| builder.divider }
    client = ApiSupport.client("xoxb-synthetic-invalid")
    request = Slack::Api::ViewsOpen.new(trigger_id: "", view: view)
    error = expect_raises(Slack::UI::ValidationError) { client.call(request) }
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"views_open.trigger_id.empty", "trigger_id"}]
    requests.should eq 0
  end

  it "rejects invalid dispatch configuration before transport" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |_request|
      requests += 1
      HTTP::Client::Response.new(500)
    end
    error = expect_raises(Slack::UI::ValidationError) do
      config = Slack::UI::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: [Slack::UI::CompositionObjects::DispatchTrigger.new(99)])
      view = Slack::UI.form_modal(title: Slack::UI.plain("Form"), submit: Slack::UI.plain("Send")) do |builder|
        builder.input(label: Slack::UI.plain("Text"), element: Slack::UI::BlockElements::PlainTextInput.new(dispatch_action_config: config))
      end
      client = ApiSupport.client("xoxb-synthetic-invalid-config")
      request = Slack::Api::ViewsOpen.new(trigger_id: "trigger", view: view)
      client.call(request)
    end
    error.issues.map(&.code).should contain("dispatch_action_config.trigger.invalid")
    requests.should eq 0
  end

  it "sends display modals without submit and retains API error handling" do
    view = Slack::UI.display_modal(title: Slack::UI.plain("Display")) { |builder| builder.section(Slack::UI.plain("Details")) }
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      JSON.parse(request.body || fail("Expected body"))["view"].as_h.has_key?("submit").should be_false
      HTTP::Client::Response.new(200, body: %({"ok":false,"error":"invalid_trigger"}))
    end
    error = expect_raises(Slack::Api::Error) { ApiSupport.client.call(Slack::Api::ViewsOpen.new(trigger_id: "trigger", view: view)) }
    error.code.should eq "invalid_trigger"
  end
end
