require "../spec_helper"
require "../support/api/webmock_client"

private def stub_agents_method(method : String, expected_body : String, response : String) : Nil
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Authorization" => "Bearer xoxb-synthetic-agent",
                    "Content-Type"  => "application/json; charset=utf-8"})
    .to_return do |request|
      JSON.parse(request.body || fail("Expected a JSON request body")).should eq JSON.parse(expected_body)
      HTTP::Client::Response.new(200, body: response)
    end
end

private def agent_client : Slack::Api::Client
  ApiSupport.client(token: "xoxb-synthetic-agent")
end

private def agent_validation_codes(&) : Array(String)
  error = expect_raises(Slack::UI::ValidationError) { yield }
  error.issues.map(&.code)
end

describe Slack::Api::AgentsSessionsSetStatus do
  it "creates a titled session and reads the session and agent status" do
    stub_agents_method("agents.sessions.setStatus", <<-JSON, <<-RESPONSE)
      {"status":"processing","channel_id":"C123","thread_ts":"1234567890.123456",
       "title":"Scuba diving research","initiator_user_id":"U123",
       "icon_url":"https://example.com/agent.png","username":"Research agent"}
      JSON
      {"ok":true,"status":"processing","agent_status":"processing","title":"Scuba diving research"}
      RESPONSE

    request = Slack::Api::AgentsSessionsSetStatus.new(
      status: Slack::Api::Streaming::SessionStatus::Processing,
      channel_id: "C123", thread_ts: "1234567890.123456", title: "Scuba diving research",
      initiator_user_id: "U123", icon: Slack::UI::Icon::Url.new("https://example.com/agent.png"),
      username: "Research agent")
    session = agent_client.call(request)

    session.status.should eq "processing"
    session.agent_status.should eq "processing"
    session.title.should eq "Scuba diving research"
  end

  it "sends only the status for a session channel" do
    stub_agents_method("agents.sessions.setStatus", %({"status":"active"}),
      %({"ok":true,"status":"processing","agent_status":"active"}))

    session = agent_client.call(Slack::Api::AgentsSessionsSetStatus.new(
      status: Slack::Api::Streaming::SessionStatus::Active))

    session.status.should eq "processing"
    session.agent_status.should eq "active"
    session.title.should be_nil
  end

  it "rejects a title or username longer than 200 characters and a malformed thread timestamp" do
    agent_validation_codes do
      agent_client.call(Slack::Api::AgentsSessionsSetStatus.new(
        status: Slack::Api::Streaming::SessionStatus::Closed, thread_ts: "0",
        title: "t" * 201, username: "u" * 201))
    end.should eq ["agents_sessions_set_status.thread_ts.invalid",
                   "agents_sessions_set_status.title.too_long",
                   "agents_sessions_set_status.username.too_long"]
  end

  it "raises the Slack error code" do
    stub_agents_method("agents.sessions.setStatus", %({"status":"suspended","channel_id":"C123"}),
      %({"ok":false,"error":"thread_ts_required"}))

    error = expect_raises(Slack::Api::Error) do
      agent_client.call(Slack::Api::AgentsSessionsSetStatus.new(
        status: Slack::Api::Streaming::SessionStatus::Suspended, channel_id: "C123"))
    end
    error.code.should eq "thread_ts_required"
  end
end

describe Slack::Api::AgentsSessionsRename do
  it "renames a thread session and reads the new title" do
    stub_agents_method("agents.sessions.rename",
      %({"title":"Bora Bora trip prep","channel_id":"C123","thread_ts":"1234567890.123456"}),
      %({"ok":true,"title":"Bora Bora trip prep"}))

    session = agent_client.call(Slack::Api::AgentsSessionsRename.new(title: "Bora Bora trip prep",
      channel_id: "C123", thread_ts: "1234567890.123456"))
    session.title.should eq "Bora Bora trip prep"
  end

  it "rejects an empty title and a title longer than 200 characters" do
    agent_validation_codes do
      agent_client.call(Slack::Api::AgentsSessionsRename.new(title: ""))
    end.should eq ["agents_sessions_rename.title.blank"]

    agent_validation_codes do
      agent_client.call(Slack::Api::AgentsSessionsRename.new(title: "t" * 201))
    end.should eq ["agents_sessions_rename.title.too_long"]
  end
end
