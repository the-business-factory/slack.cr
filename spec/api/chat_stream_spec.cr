require "../spec_helper"
require "../support/api/webmock_client"

private def stub_stream_method(method : String, expected : JSON::Any, response : String = %({"ok":true,"channel":"C123","ts":"1721609600.123456"})) : Array(Int32)
  count = [0]
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Authorization" => "Bearer xoxb-synthetic-stream", "Content-Type" => "application/json; charset=utf-8"})
    .to_return do |http_request|
      count[0] += 1
      JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
      HTTP::Client::Response.new(200, body: response)
    end
  count
end

private def stream_divider_blocks(count : Int32) : Array(Slack::UI::Blocks::Divider)
  Array.new(count) { Slack::UI::Blocks::Divider.new }
end

describe Slack::Api::ChatStartStream do
  it "starts a markdown stream in a thread and returns its message stream" do
    expected = JSON.parse(<<-JSON)
      {"channel":"C123","thread_ts":"1721609600.000001","recipient_user_id":"U123",
       "recipient_team_id":"T123","markdown_text":"Looking into it...","username":"Helper"}
      JSON
    count = stub_stream_method("chat.startStream", expected)
    request = Slack::Api::ChatStartStream.new(channel: "C123", thread_ts: "1721609600.000001",
      recipient_user_id: "U123", recipient_team_id: "T123",
      markdown_text: "Looking into it...", username: "Helper")

    stream = ApiSupport.client("xoxb-synthetic-stream").start_stream(request)

    stream.channel.should eq "C123"
    stream.ts.should eq "1721609600.123456"
    count[0].should eq 1
  end

  it "starts a plan-mode stream with task updates" do
    expected = JSON.parse(<<-JSON)
      {"channel":"D123","task_display_mode":"plan","chunks":[
        {"type":"task_update","id":"fetch","title":"Fetch the report","status":"in_progress"},
        {"type":"task_update","id":"sum","title":"Summarize","status":"complete","hide_title":false,
         "icon":{"type":"icon","name":"https://example.com/robot.png"},
         "details":"Read 3 pages","output":"Revenue grew 4%",
         "sources":[{"type":"url","url":"https://example.com/report","text":"Q3 report"}]}
      ]}
      JSON
    count = stub_stream_method("chat.startStream", expected)
    sources = [Slack::UI::BlockElements::UrlSource.new(url: "https://example.com/report", text: "Q3 report")]
    summary = Slack::Api::Streaming::TaskUpdateChunk.new(id: "sum", title: "Summarize",
      status: Slack::UI::TaskStatus::Complete, hide_title: false,
      icon: Slack::Api::Streaming::IconRef.new("https://example.com/robot.png"),
      details: "Read 3 pages", output: "Revenue grew 4%", sources: sources)
    sources.clear
    chunks = [
      Slack::Api::Streaming::TaskUpdateChunk.new(id: "fetch", title: "Fetch the report",
        status: Slack::UI::TaskStatus::InProgress),
      summary,
    ]
    request = Slack::Api::ChatStartStream.new(channel: "D123", chunks: chunks,
      task_display_mode: Slack::Api::Streaming::TaskDisplayMode::Plan)
    chunks.clear

    ApiSupport.client("xoxb-synthetic-stream").call(request).ts.should eq "1721609600.123456"
    count[0].should eq 1
  end

  it "rejects invalid fields before transport" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/chat.startStream").to_return do |_request|
      requests += 1
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C1","ts":"1.1"}))
    end
    client = ApiSupport.client("xoxb-synthetic-stream")
    {
      {Slack::Api::ChatStartStream.new(channel: " ", markdown_text: "Hi"), "chat_start_stream.channel.blank", "channel"},
      {Slack::Api::ChatStartStream.new(channel: "C1", thread_ts: "0", markdown_text: "Hi"), "chat_start_stream.thread_ts.invalid", "thread_ts"},
      {Slack::Api::ChatStartStream.new(channel: "C1", markdown_text: ""), "chat_start_stream.markdown_text.empty", "markdown_text"},
      {Slack::Api::ChatStartStream.new(channel: "C1", markdown_text: "é" * 12_001), "chat_start_stream.markdown_text.too_long", "markdown_text"},
      {Slack::Api::ChatStartStream.new(channel: "C1", chunks: [] of Slack::Api::Streaming::Chunk), "chat_start_stream.chunks.empty", "chunks"},
      {Slack::Api::ChatStartStream.new(channel: "C1", recipient_user_id: "U1"), "chat_start_stream.recipient.incomplete", "recipient_team_id"},
    }.each do |request, code, path|
      error = expect_raises(Slack::UI::ValidationError) { client.call(request) }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{code, path}]
    end
    requests.should eq 0
  end
end

describe Slack::Api::MessageStream do
  it "appends a plan title and stops in the same chunk mode with blocks and a session status" do
    append = JSON.parse(%({"channel":"C123","ts":"1721609600.123456","chunks":[{"type":"plan_update","title":"Answer the question"}]}))
    stop = JSON.parse(<<-JSON)
      {"channel":"C123","ts":"1721609600.123456","chunks":[{"type":"markdown_text","text":"Done."}],
       "blocks":[{"type":"divider"},{"type":"section","text":{"type":"mrkdwn","text":"Was this helpful?"}}],
       "session_status":"closed"}
      JSON
    appended = stub_stream_method("chat.appendStream", append)
    stopped = stub_stream_method("chat.stopStream", stop,
      %({"ok":true,"channel":"C123","ts":"1721609600.123456","message":{"type":"message","text":"Done."}}))
    client = ApiSupport.client("xoxb-synthetic-stream")
    stream = Slack::Api::MessageStream.new(channel: "C123", ts: "1721609600.123456")
    blocks = [
      Slack::UI::Blocks::Divider.new,
      Slack::UI::Blocks::Section.new(text: Slack::UI.mrkdwn("Was this helpful?")),
    ]

    stream.append(client, chunks: [Slack::Api::Streaming::PlanUpdateChunk.new("Answer the question")])
    response = stream.stop(client, chunks: [Slack::Api::Streaming::MarkdownTextChunk.new("Done.")], blocks: blocks,
      session_status: Slack::Api::Streaming::SessionStatus::Closed)

    response.message.should_not(be_nil)["text"].as_s.should eq "Done."
    appended[0].should eq 1
    stopped[0].should eq 1
  end

  it "reports Slack's streaming errors by code" do
    WebMock.stub(:post, "https://slack.com/api/chat.appendStream")
      .to_return(body: %({"ok":false,"error":"message_not_in_streaming_state"}))
    stream = Slack::Api::MessageStream.new(channel: "C123", ts: "1721609600.123456")

    error = expect_raises(Slack::Api::Error) do
      stream.append(ApiSupport.client("xoxb-synthetic-stream"), markdown_text: "more")
    end
    error.code.should eq "message_not_in_streaming_state"
  end
end

describe "stream content limits" do
  it "rejects 51 blocks in a chunk or in the final blocks" do
    error = expect_raises(Slack::UI::ValidationError) do
      Slack::Api::Streaming::BlocksChunk.new(stream_divider_blocks(51))
    end
    error.issues.map(&.code).should eq ["message.blocks.too_many"]
    expect_raises(Slack::UI::ValidationError) do
      Slack::Api::ChatStopStream.new(channel: "C1", ts: "1.1", blocks: stream_divider_blocks(51))
    end
    Slack::Api::Streaming::BlocksChunk.new(stream_divider_blocks(50)).blocks.size.should eq 50
  end

  it "rejects plan and task titles over 256 characters" do
    Slack::Api::Streaming::PlanUpdateChunk.new("é" * 256).title.size.should eq 256
    error = expect_raises(Slack::UI::ValidationError) { Slack::Api::Streaming::PlanUpdateChunk.new("é" * 257) }
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"plan_update.title.too_long", "title"}]
    error = expect_raises(Slack::UI::ValidationError) do
      Slack::Api::Streaming::TaskUpdateChunk.new(id: "t", title: "é" * 257, status: Slack::UI::TaskStatus::Error)
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"task_update.title.too_long", "title"}]
  end

  it "sends a blocks chunk and a pending task through append" do
    expected = JSON.parse(<<-JSON)
      {"channel":"C123","ts":"1721609600.123456","chunks":[
        {"type":"blocks","blocks":[{"type":"divider"}]},
        {"type":"task_update","id":"next","title":"Queue the follow-up","status":"pending"}
      ]}
      JSON
    count = stub_stream_method("chat.appendStream", expected)
    chunks = [
      Slack::Api::Streaming::BlocksChunk.new([Slack::UI::Blocks::Divider.new]),
      Slack::Api::Streaming::TaskUpdateChunk.new(id: "next", title: "Queue the follow-up",
        status: Slack::UI::TaskStatus::Pending),
    ]
    Slack::Api::MessageStream.new(channel: "C123", ts: "1721609600.123456")
      .append(ApiSupport.client("xoxb-synthetic-stream"), chunks: chunks)
    count[0].should eq 1
  end
end
