require "../spec_helper"
require "../support/api/webmock_client"
require "../support/block_kit/home_fixture"

describe Slack::Api::ViewsPublish do
  it "sends the complete structured Home snapshot once" do
    builder = HomeFixture.builder
    view = builder.build
    client = ApiSupport.client("xoxb-synthetic-home")
    request = Slack::Api::ViewsPublish.new(user_id: "U123", view: view,
      hash: "1710000000.000001", interactivity_pointer: "synthetic-pointer")
    builder.divider
    view.blocks.each { |block| block.elements.clear if block.is_a?(Slack::UI::Blocks::Context) }
    view.blocks.clear
    count = 0
    WebMock.stub(:post, "https://slack.com/api/views.publish")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic-home", "Content-Type" => "application/json; charset=utf-8"})
      .to_return do |http_request|
        count += 1
        body = JSON.parse(http_request.body || fail("Expected JSON body"))
        body.should eq JSON.parse(File.read("spec/fixtures/block_kit/phase_4_views_publish.json"))
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V123","type":"home","hash":"new-hash","future":true}}))
      end
    response = client.call(request)
    response.view["id"].as_s.should eq "V123"
    response.view["future"].as_bool.should be_true
    response.view["hash"].as_s.should eq "new-hash"
    count.should eq 1
  end

  it "rejects an empty user before transport" do
    count = 0
    WebMock.stub(:post, "https://slack.com/api/views.publish").to_return do |_request|
      count += 1
      HTTP::Client::Response.new(500)
    end
    client = ApiSupport.client("xoxb-synthetic-invalid")
    request = Slack::Api::ViewsPublish.new(user_id: "", view: HomeFixture.builder.build)
    error = expect_raises(Slack::UI::ValidationError) { client.call(request) }
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"views_publish.user_id.empty", "user_id"}]
    expect_raises(Slack::UI::ValidationError) { request.to_json }
    count.should eq 0
  end

  it "rejects invalid Home focus before transport" do
    count = 0
    WebMock.stub(:post, "https://slack.com/api/views.publish").to_return do |_request|
      count += 1
      HTTP::Client::Response.new(500)
    end
    error = expect_raises(Slack::UI::ValidationError) do
      builder = HomeFixture.builder
      builder.input(label: Slack::UI.plain("Second"), element: Slack::UI::BlockElements::PlainTextInput.new(focus_on_load: true))
      client = ApiSupport.client("xoxb-synthetic-focus")
      request = Slack::Api::ViewsPublish.new(user_id: "U123", view: builder.build)
      client.call(request)
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"home.focus_on_load.duplicate", "blocks[7].element.focus_on_load"}]
    count.should eq 0
  end

  it "omits optional request fields and sends an empty Home" do
    client = ApiSupport.client("xoxb-synthetic-minimal")
    request = Slack::Api::ViewsPublish.new(user_id: "U123", view: Slack::UI.home { |_builder| })
    expected = JSON.parse(File.read("spec/fixtures/block_kit/phase_4_views_publish_minimal.json"))
    JSON.parse(request.to_json).should eq expected
    WebMock.stub(:post, "https://slack.com/api/views.publish").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"type":"home","blocks":[]}}))
    end
    client.call(request).ok?.should be_true
  end

  it "preserves explicit empty opaque request values and Slack API errors" do
    client = ApiSupport.client("xoxb-synthetic-error")
    request = Slack::Api::ViewsPublish.new(user_id: "U123", view: Slack::UI.home { |_builder| }, hash: "", interactivity_pointer: "")
    body = JSON.parse(request.to_json)
    body["hash"].as_s.should eq ""
    body["interactivity_pointer"].as_s.should eq ""
    WebMock.stub(:post, "https://slack.com/api/views.publish").to_return(body: %({"ok":false,"error":"hash_conflict"}))
    expect_raises(Slack::Api::Error) { client.call(request) }
  end
end
