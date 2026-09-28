require "../spec_helper"
require "../support/auth/webmock_transport"
require "../support/block_kit/home_fixture"

describe Slack::Api::CheckedViewsPublish do
  ["result", "call"].each do |entrypoint|
    it "sends the complete structured Home snapshot once through #{entrypoint}" do
      builder = HomeFixture.builder
      view = builder.build
      request = Slack::Api::CheckedViewsPublish.new(token: "xoxb-synthetic-home-#{entrypoint}", user_id: "U123", view: view,
        hash: "1710000000.000001", interactivity_pointer: "synthetic-pointer", transport: AuthSupport::WebMockTransport.new)
      builder.divider
      view.blocks.each { |block| block.elements.clear if block.is_a?(Slack::UI::Checked::Blocks::Context) }
      view.blocks.clear
      count = 0
      WebMock.stub(:post, "https://slack.com/api/views.publish")
        .with(headers: {"Authorization" => "Bearer xoxb-synthetic-home-#{entrypoint}", "Content-Type" => "application/json; charset=utf-8"})
        .to_return do |http_request|
          count += 1
          body = JSON.parse(http_request.body || fail("Expected JSON body"))
          body.should eq JSON.parse(File.read("spec/fixtures/block_kit/phase_4_views_publish.json"))
          HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V123","type":"home","hash":"new-hash","future":true}}))
        end
      entrypoint == "result" ? request.result.status_code.should(eq 200) : request.call.view["id"].as_s.should(eq "V123")
      request.call.view["future"].as_bool.should be_true
      request.call.view["hash"].as_s.should eq "new-hash"
      count.should eq 1
    end

    it "rejects an empty user before #{entrypoint} transport" do
      count = 0
      WebMock.stub(:post, "https://slack.com/api/views.publish").to_return do |_request|
        count += 1
        HTTP::Client::Response.new(500)
      end
      request = Slack::Api::CheckedViewsPublish.new(token: "xoxb-synthetic-invalid", user_id: "", view: HomeFixture.builder.build, transport: AuthSupport::WebMockTransport.new)
      error = expect_raises(Slack::UI::Checked::ValidationError) { entrypoint == "result" ? request.result : request.call }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"views_publish.user_id.empty", "user_id"}]
      expect_raises(Slack::UI::Checked::ValidationError) { request.to_json }
      count.should eq 0
    end

    it "rejects invalid Home focus before #{entrypoint} transport" do
      count = 0
      WebMock.stub(:post, "https://slack.com/api/views.publish").to_return do |_request|
        count += 1
        HTTP::Client::Response.new(500)
      end
      error = expect_raises(Slack::UI::Checked::ValidationError) do
        builder = HomeFixture.builder
        builder.input(label: Slack::UI::Checked.plain("Second"), element: Slack::UI::Checked::BlockElements::PlainTextInput.new(focus_on_load: true))
        request = Slack::Api::CheckedViewsPublish.new(token: "xoxb-synthetic-focus", user_id: "U123", view: builder.build, transport: AuthSupport::WebMockTransport.new)
        entrypoint == "result" ? request.result : request.call
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"home.focus_on_load.duplicate", "blocks[7].element.focus_on_load"}]
      count.should eq 0
    end
  end

  it "omits optional request fields and sends an empty Home" do
    request = Slack::Api::CheckedViewsPublish.new(token: "xoxb-synthetic-minimal", user_id: "U123", view: Slack::UI::Checked.home { |_builder| }, transport: AuthSupport::WebMockTransport.new)
    expected = JSON.parse(File.read("spec/fixtures/block_kit/phase_4_views_publish_minimal.json"))
    JSON.parse(request.to_json).should eq expected
    WebMock.stub(:post, "https://slack.com/api/views.publish").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"type":"home","blocks":[]}}))
    end
    request.call.ok?.should be_true
  end

  it "preserves explicit empty opaque request values and Slack API errors" do
    request = Slack::Api::CheckedViewsPublish.new(token: "xoxb-synthetic-error", user_id: "U123", view: Slack::UI::Checked.home { |_builder| }, hash: "", interactivity_pointer: "", transport: AuthSupport::WebMockTransport.new)
    body = JSON.parse(request.to_json)
    body["hash"].as_s.should eq ""
    body["interactivity_pointer"].as_s.should eq ""
    WebMock.stub(:post, "https://slack.com/api/views.publish").to_return(body: %({"ok":false,"error":"hash_conflict"}))
    expect_raises(Slack::Errors::Api) { request.call }
  end
end
