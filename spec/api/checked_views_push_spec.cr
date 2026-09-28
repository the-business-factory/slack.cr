require "../spec_helper"
require "../support/auth/webmock_transport"

describe Slack::Api::CheckedViewsPush do
  it "pushes an owned form snapshot and parses the cached response" do
    builder = Slack::UI::Checked::FormModalBuilder.new(
      title: Slack::UI::Checked.plain("Details"), submit: Slack::UI::Checked.plain("Save"),
      close: Slack::UI::Checked.plain("Back"), external_id: "request-42-details",
      private_metadata: %({"request":42}), callback_id: "request.details",
      clear_on_close: false, notify_on_close: false, submit_disabled: false)
    builder.input(label: Slack::UI::Checked.plain("Reason"), block_id: "reason", optional: false,
      element: Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "text", multiline: false))
    view = builder.build
    request = Slack::Api::CheckedViewsPush.new(token: "xoxb-synthetic-push",
      trigger_id: "opaque-trigger", view: view, transport: AuthSupport::WebMockTransport.new)
    builder.divider
    view.blocks.clear
    # Independently authored wire contract, not serialized from the checked view.
    expected = JSON.parse(<<-JSON)
      {"trigger_id":"opaque-trigger","view":{
        "type":"modal","title":{"type":"plain_text","text":"Details"},
        "submit":{"type":"plain_text","text":"Save"},"close":{"type":"plain_text","text":"Back"},
        "external_id":"request-42-details","private_metadata":"{\\"request\\":42}",
        "callback_id":"request.details","clear_on_close":false,"notify_on_close":false,"submit_disabled":false,
        "blocks":[{"type":"input","block_id":"reason","label":{"type":"plain_text","text":"Reason"},
          "optional":false,"element":{"type":"plain_text_input","action_id":"text","multiline":false}}]}}
      JSON
    JSON.parse(request.to_json).should eq expected
    count = 0
    WebMock.stub(:post, "https://slack.com/api/views.push")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic-push", "Content-Type" => "application/json; charset=utf-8"})
      .to_return do |http_request|
        count += 1
        JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V2","type":"modal","root_view_id":"V1","previous_view_id":"V1","hash":"pushed-hash","state":{"values":{}},"future":true}}))
      end
    request.result.status_code.should eq 200
    response = request.call
    response.ok?.should be_true
    response.view["id"].as_s.should eq "V2"
    response.view["root_view_id"].as_s.should eq "V1"
    response.view["previous_view_id"].as_s.should eq "V1"
    response.view["hash"].as_s.should eq "pushed-hash"
    response.view["state"]["values"].as_h.should be_empty
    response.view["future"].as_bool.should be_true
    request.call
    count.should eq 1
  end

  ["result", "call"].each do |entrypoint|
    it "rejects blank triggers before #{entrypoint} transport" do
      count = 0
      WebMock.stub(:post, "https://slack.com/api/views.push").to_return do |_request|
        count += 1
        HTTP::Client::Response.new(500)
      end
      view = Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Status"), &.divider)
      ["", "  "].each do |trigger|
        request = Slack::Api::CheckedViewsPush.new(token: "xoxb-synthetic-invalid", trigger_id: trigger,
          view: view, transport: AuthSupport::WebMockTransport.new)
        error = expect_raises(Slack::UI::Checked::ValidationError) { entrypoint == "result" ? request.result : request.call }
        error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"views_push.trigger_id.blank", "trigger_id"}]
        expect_raises(Slack::UI::Checked::ValidationError) { request.to_json }
      end
      count.should eq 0
    end

    it "rejects invalid modal contents before #{entrypoint} transport" do
      count = 0
      WebMock.stub(:post, "https://slack.com/api/views.push").to_return do |_request|
        count += 1
        HTTP::Client::Response.new(500)
      end
      error = expect_raises(Slack::UI::Checked::ValidationError) do
        view = Slack::UI::Checked.form_modal(title: Slack::UI::Checked.plain("Details"), submit: Slack::UI::Checked.plain("Save")) do |builder|
          builder.input(label: Slack::UI::Checked.plain("Reason"), block_id: "reason",
            element: Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "text"))
          builder.divider(block_id: "reason")
        end
        request = Slack::Api::CheckedViewsPush.new(token: "xoxb-synthetic-invalid", trigger_id: "trigger", view: view,
          transport: AuthSupport::WebMockTransport.new)
        entrypoint == "result" ? request.result : request.call
      end
      error.issues.map(&.code).should contain("modal.block_id.duplicate")
      count.should eq 0
    end
  end

  it "pushes a display modal without submit or unrelated envelope fields" do
    view = Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Status"), &.divider)
    request = Slack::Api::CheckedViewsPush.new(token: "xoxb-synthetic-display", trigger_id: "display-trigger", view: view,
      transport: AuthSupport::WebMockTransport.new)
    expected = JSON.parse(%({"trigger_id":"display-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Status"},"blocks":[{"type":"divider"}]}}))
    JSON.parse(request.to_json).should eq expected
    WebMock.stub(:post, "https://slack.com/api/views.push").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V2","root_view_id":"V1","previous_view_id":null}}))
    end
    response = request.call
    response.view["id"].as_s.should eq "V2"
    response.view["previous_view_id"].raw.should be_nil
  end

  ["expired_trigger_id", "push_limit_reached"].each do |failure|
    it "caches #{failure} and raises the established API error without retry" do
      count = 0
      WebMock.stub(:post, "https://slack.com/api/views.push").to_return do |_request|
        count += 1
        HTTP::Client::Response.new(200, body: %({"ok":false,"error":"#{failure}"}))
      end
      request = Slack::Api::CheckedViewsPush.new(token: "xoxb-synthetic-error", trigger_id: "trigger",
        view: Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Status"), &.divider),
        transport: AuthSupport::WebMockTransport.new)
      2.times { expect_raises(Slack::Errors::Api, failure) { request.call } }
      JSON.parse(request.result.body)["error"].as_s.should eq failure
      count.should eq 1
    end
  end
end
