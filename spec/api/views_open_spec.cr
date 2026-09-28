require "../spec_helper"
require "../support/auth/webmock_transport"

describe Slack::Api::CheckedViewsOpen do
  ["result", "call"].each do |entrypoint|
    it "sends a structured form snapshot with external_id inside view through #{entrypoint}" do
      builder = Slack::UI::Checked::FormModalBuilder.new(title: Slack::UI::Checked.plain("Request"), submit: Slack::UI::Checked.plain("Send"), external_id: "request-42")
      builder.input(label: Slack::UI::Checked.plain("Reason"), block_id: "reason", element: Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "text"))
      view = builder.build
      request = Slack::Api::CheckedViewsOpen.new(transport: AuthSupport::WebMockTransport.new, token: "xoxb-synthetic-#{entrypoint}", trigger_id: "synthetic-trigger", view: view)
      expected_view = JSON.parse(view.to_json)
      builder.divider
      view.blocks.clear
      requests = 0
      WebMock.stub(:post, "https://slack.com/api/views.open")
        .with(headers: {"Authorization" => "Bearer xoxb-synthetic-#{entrypoint}"})
        .to_return do |http_request|
          requests += 1
          body = JSON.parse(http_request.body || fail("Expected JSON body"))
          body.as_h.keys.sort!.should eq ["trigger_id", "view"]
          body["trigger_id"].as_s.should eq "synthetic-trigger"
          body["view"].should eq expected_view
          body["view"]["external_id"].as_s.should eq "request-42"
          HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V123"}}))
        end
      entrypoint == "result" ? request.result.status_code.should(eq 200) : request.call.view["id"].as_s.should(eq "V123")
      request.result.status_code.should eq 200
      requests.should eq 1
    end

    it "validates trigger_id through #{entrypoint} before any HTTP" do
      requests = 0
      WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |_request|
        requests += 1
        HTTP::Client::Response.new(500)
      end
      view = Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Display")) { |builder| builder.divider }
      request = Slack::Api::CheckedViewsOpen.new(transport: AuthSupport::WebMockTransport.new, token: "xoxb-synthetic-invalid", trigger_id: "", view: view)
      error = expect_raises(Slack::UI::Checked::ValidationError) { entrypoint == "result" ? request.result : request.call }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"views_open.trigger_id.empty", "trigger_id"}]
      requests.should eq 0
    end

    it "rejects invalid dispatch configuration before #{entrypoint} transport" do
      requests = 0
      WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |_request|
        requests += 1
        HTTP::Client::Response.new(500)
      end
      error = expect_raises(Slack::UI::Checked::ValidationError) do
        config = Slack::UI::Checked::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: [Slack::UI::Checked::CompositionObjects::DispatchTrigger.new(99)])
        view = Slack::UI::Checked.form_modal(title: Slack::UI::Checked.plain("Form"), submit: Slack::UI::Checked.plain("Send")) do |builder|
          builder.input(label: Slack::UI::Checked.plain("Text"), element: Slack::UI::Checked::BlockElements::PlainTextInput.new(dispatch_action_config: config))
        end
        request = Slack::Api::CheckedViewsOpen.new(transport: AuthSupport::WebMockTransport.new, token: "xoxb-synthetic-invalid-config", trigger_id: "trigger", view: view)
        entrypoint == "result" ? request.result : request.call
      end
      error.issues.map(&.code).should contain("dispatch_action_config.trigger.invalid")
      requests.should eq 0
    end
  end

  it "sends display modals without submit and retains API error handling" do
    view = Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Display")) { |builder| builder.section(Slack::UI::Checked.plain("Details")) }
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      JSON.parse(request.body || fail("Expected body"))["view"].as_h.has_key?("submit").should be_false
      HTTP::Client::Response.new(200, body: %({"ok":false,"error":"invalid_trigger"}))
    end
    expect_raises(Slack::Errors::Api) { Slack::Api::CheckedViewsOpen.new(transport: AuthSupport::WebMockTransport.new, token: "xoxb-synthetic-error", trigger_id: "trigger", view: view).call }
  end
end
