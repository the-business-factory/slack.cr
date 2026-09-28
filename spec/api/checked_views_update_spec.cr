require "../spec_helper"
require "../support/auth/webmock_transport"

describe Slack::Api::CheckedViewsUpdate do
  it "updates an owned form snapshot with distinct target and view metadata once" do
    builder = Slack::UI::Checked::FormModalBuilder.new(
      title: Slack::UI::Checked.plain("Request"), submit: Slack::UI::Checked.plain("Save"),
      external_id: "request-42-next", private_metadata: "42", callback_id: "request",
      notify_on_close: false)
    builder.input(label: Slack::UI::Checked.plain("Reason"), block_id: "reason", optional: false,
      element: Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "text", multiline: true))
    view = builder.build
    request = Slack::Api::CheckedViewsUpdate.new(token: "xoxb-synthetic-update",
      external_id: "request-42", view: view, hash: "opaque/hash.v1",
      transport: AuthSupport::WebMockTransport.new)
    builder.divider
    view.blocks.clear
    expected = JSON.parse(<<-JSON)
      {"external_id":"request-42","hash":"opaque/hash.v1","view":{
        "type":"modal","title":{"type":"plain_text","text":"Request"},
        "submit":{"type":"plain_text","text":"Save"},"external_id":"request-42-next",
        "private_metadata":"42","callback_id":"request","notify_on_close":false,
        "blocks":[{"type":"input","block_id":"reason","label":{"type":"plain_text","text":"Reason"},
          "optional":false,"element":{"type":"plain_text_input","action_id":"text","multiline":true}}]}}
      JSON
    JSON.parse(request.to_json).should eq expected
    count = 0
    WebMock.stub(:post, "https://slack.com/api/views.update")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic-update", "Content-Type" => "application/json; charset=utf-8"})
      .to_return do |http_request|
        count += 1
        JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V123","type":"modal","external_id":"request-42-next","hash":"new-hash","state":{"values":{"reason":{"text":{"type":"plain_text_input","value":"Need access"}}}},"future":true}}))
      end
    request.result.status_code.should eq 200
    response = request.call
    response.ok?.should be_true
    response.view["id"].as_s.should eq "V123"
    response.view["hash"].as_s.should eq "new-hash"
    response.view["state"]["values"]["reason"]["text"]["value"].as_s.should eq "Need access"
    response.view["future"].as_bool.should be_true
    request.call
    count.should eq 1
  end

  ["result", "call"].each do |entrypoint|
    it "rejects missing, ambiguous, or invalid selectors before #{entrypoint} transport" do
      count = 0
      WebMock.stub(:post, "https://slack.com/api/views.update").to_return do |_request|
        count += 1
        HTTP::Client::Response.new(500)
      end
      # Nested metadata must never supply a missing target selector.
      view = Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Status"), external_id: "nested", &.divider)
      {
        {nil, nil, "views_update.target.required", "view_id"},
        {"V123", "target", "views_update.target.ambiguous", "external_id"},
        {"", nil, "views_update.view_id.blank", "view_id"},
        {"  ", nil, "views_update.view_id.blank", "view_id"},
        {nil, "", "views_update.external_id.blank", "external_id"},
        {nil, "  ", "views_update.external_id.blank", "external_id"},
        {nil, "é" * 256, "views_update.external_id.too_long", "external_id"},
      }.each do |view_id, external_id, code, path|
        request = Slack::Api::CheckedViewsUpdate.new(token: "xoxb-synthetic-invalid", view: view,
          view_id: view_id, external_id: external_id, transport: AuthSupport::WebMockTransport.new)
        error = expect_raises(Slack::UI::Checked::ValidationError) { entrypoint == "result" ? request.result : request.call }
        error.issues.map { |issue| {issue.code, issue.path} }.should eq [{code, path}]
        expect_raises(Slack::UI::Checked::ValidationError) { request.to_json }
      end
      count.should eq 0
    end

    it "rejects invalid modal contents before #{entrypoint} transport" do
      count = 0
      WebMock.stub(:post, "https://slack.com/api/views.update").to_return do |_request|
        count += 1
        HTTP::Client::Response.new(500)
      end
      error = expect_raises(Slack::UI::Checked::ValidationError) do
        view = Slack::UI::Checked.form_modal(title: Slack::UI::Checked.plain("Request"), submit: Slack::UI::Checked.plain("Save")) do |builder|
          builder.input(label: Slack::UI::Checked.plain("Reason"), block_id: "reason",
            element: Slack::UI::Checked::BlockElements::PlainTextInput.new(action_id: "text"))
          builder.divider(block_id: "reason")
        end
        request = Slack::Api::CheckedViewsUpdate.new(token: "xoxb-synthetic-invalid-view", view_id: "V123", view: view,
          transport: AuthSupport::WebMockTransport.new)
        entrypoint == "result" ? request.result : request.call
      end
      error.issues.map(&.code).should contain("modal.block_id.duplicate")
      count.should eq 0
    end
  end

  it "updates a display modal by view ID without hash or inferred metadata" do
    view = Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Status"), &.divider)
    request = Slack::Api::CheckedViewsUpdate.new(token: "xoxb-synthetic-display", view_id: "V123", view: view,
      transport: AuthSupport::WebMockTransport.new)
    expected = JSON.parse(%({"view_id":"V123","view":{"type":"modal","title":{"type":"plain_text","text":"Status"},"blocks":[{"type":"divider"}]}}))
    WebMock.stub(:post, "https://slack.com/api/views.update").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V123","type":"modal","hash":"next"}}))
    end
    request.call.view["id"].as_s.should eq "V123"
  end

  it "preserves an empty opaque hash and a 255-character external selector" do
    request = Slack::Api::CheckedViewsUpdate.new(token: "xoxb-synthetic-boundary", external_id: "é" * 255, hash: "",
      view: Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Status"), &.divider),
      transport: AuthSupport::WebMockTransport.new)
    WebMock.stub(:post, "https://slack.com/api/views.update").to_return do |http_request|
      body = JSON.parse(http_request.body || fail("Expected JSON body"))
      body["external_id"].as_s.should eq "é" * 255
      body["hash"].as_s.should eq ""
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V123"}}))
    end
    request.call.ok?.should be_true
  end

  ["not_found", "hash_conflict"].each do |failure|
    it "caches #{failure} and raises the established API error without retry" do
      count = 0
      WebMock.stub(:post, "https://slack.com/api/views.update").to_return do |_request|
        count += 1
        HTTP::Client::Response.new(200, body: %({"ok":false,"error":"#{failure}"}))
      end
      request = Slack::Api::CheckedViewsUpdate.new(token: "xoxb-synthetic-error", view_id: "V123", hash: "old-hash",
        view: Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Status"), &.divider),
        transport: AuthSupport::WebMockTransport.new)
      2.times { expect_raises(Slack::Errors::Api, failure) { request.call } }
      JSON.parse(request.result.body)["error"].as_s.should eq failure
      count.should eq 1
    end
  end
end
