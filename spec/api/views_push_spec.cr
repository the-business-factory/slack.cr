require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ViewsPush do
  it "pushes an owned form snapshot and parses the cached response" do
    builder = Slack::UI::FormModalBuilder.new(
      title: Slack::UI.plain("Details"), submit: Slack::UI.plain("Save"),
      close: Slack::UI.plain("Back"), external_id: "request-42-details",
      private_metadata: %({"request":42}), callback_id: "request.details",
      clear_on_close: false, notify_on_close: false, submit_disabled: false)
    builder.input(label: Slack::UI.plain("Reason"), block_id: "reason", optional: false,
      element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "text", multiline: false))
    view = builder.build
    client = ApiSupport.client("xoxb-synthetic-push")
    request = Slack::Api::ViewsPush.new(trigger_id: "opaque-trigger", view: view)
    builder.divider
    view.blocks.clear
    # Independently authored wire contract, not serialized from the view.
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
    response = client.call(request)
    response.ok?.should be_true
    response.view["id"].as_s.should eq "V2"
    response.view["root_view_id"].as_s.should eq "V1"
    response.view["previous_view_id"].as_s.should eq "V1"
    response.view["hash"].as_s.should eq "pushed-hash"
    response.view["state"]["values"].as_h.should be_empty
    response.view["future"].as_bool.should be_true
    count.should eq 1
  end

  it "rejects blank triggers before transport" do
    count = 0
    WebMock.stub(:post, "https://slack.com/api/views.push").to_return do |_request|
      count += 1
      HTTP::Client::Response.new(500)
    end
    view = Slack::UI.display_modal(title: Slack::UI.plain("Status"), &.divider)
    ["", "  "].each do |trigger|
      client = ApiSupport.client("xoxb-synthetic-invalid")
      request = Slack::Api::ViewsPush.new(trigger_id: trigger,
        view: view)
      error = expect_raises(Slack::UI::ValidationError) { client.call(request) }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"views_push.trigger_id.blank", "trigger_id"}]
      expect_raises(Slack::UI::ValidationError) { request.to_json }
    end
    count.should eq 0
  end

  it "rejects invalid modal contents before transport" do
    count = 0
    WebMock.stub(:post, "https://slack.com/api/views.push").to_return do |_request|
      count += 1
      HTTP::Client::Response.new(500)
    end
    error = expect_raises(Slack::UI::ValidationError) do
      view = Slack::UI.form_modal(title: Slack::UI.plain("Details"), submit: Slack::UI.plain("Save")) do |builder|
        builder.input(label: Slack::UI.plain("Reason"), block_id: "reason",
          element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "text"))
        builder.divider(block_id: "reason")
      end
      client = ApiSupport.client("xoxb-synthetic-invalid")
      request = Slack::Api::ViewsPush.new(trigger_id: "trigger", view: view)
      client.call(request)
    end
    error.issues.map(&.code).should contain("modal.block_id.duplicate")
    count.should eq 0
  end

  it "pushes a display modal without submit or unrelated envelope fields" do
    view = Slack::UI.display_modal(title: Slack::UI.plain("Status"), &.divider)
    client = ApiSupport.client("xoxb-synthetic-display")
    request = Slack::Api::ViewsPush.new(trigger_id: "display-trigger", view: view)
    expected = JSON.parse(%({"trigger_id":"display-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Status"},"blocks":[{"type":"divider"}]}}))
    JSON.parse(request.to_json).should eq expected
    WebMock.stub(:post, "https://slack.com/api/views.push").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V2","root_view_id":"V1","previous_view_id":null}}))
    end
    response = client.call(request)
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
      client = ApiSupport.client("xoxb-synthetic-error")
      request = Slack::Api::ViewsPush.new(trigger_id: "trigger",
        view: Slack::UI.display_modal(title: Slack::UI.plain("Status"), &.divider))
      expect_raises(Slack::Api::Error) { client.call(request) }.code.should eq failure
      count.should eq 1
    end
  end
end
