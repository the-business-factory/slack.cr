require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Streams an answer in a thread in chunk mode: start with text, append a plan, stop with feedback blocks.
# Slack requires every call of one stream to use the content mode that started it.
module OfflineStreamingExample
  STREAM = %({"ok":true,"channel":"C123","ts":"1721609600.123456"})

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-streaming", transport: OfflineExample::WebMockTransport.new)
    WebMock.stub(:post, "https://slack.com/api/chat.startStream")
      .with(body: %({"channel":"C123","thread_ts":"1721609600.000001","recipient_user_id":"U123","recipient_team_id":"T123","task_display_mode":"plan","chunks":[{"type":"markdown_text","text":"Checking the report."}]}))
      .to_return(body: STREAM)
    WebMock.stub(:post, "https://slack.com/api/chat.appendStream")
      .with(body: %({"channel":"C123","ts":"1721609600.123456","chunks":[{"type":"plan_update","title":"Answer the question"},{"type":"task_update","id":"read","title":"Read the report","status":"complete","sources":[{"type":"url","url":"https://example.com/q3","text":"Q3 report"}]}]}))
      .to_return(body: STREAM)
    WebMock.stub(:post, "https://slack.com/api/chat.stopStream")
      .with(body: %({"channel":"C123","ts":"1721609600.123456","chunks":[{"type":"markdown_text","text":"Revenue grew 4%."}],"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"Was this helpful?"}}],"session_status":"closed"}))
      .to_return(body: %({"ok":true,"channel":"C123","ts":"1721609600.123456","message":{"type":"message","text":"Checking the report. Revenue grew 4%."}}))

    stream = client.start_stream(Slack::Api::ChatStartStream.new(
      channel: "C123", thread_ts: "1721609600.000001",
      recipient_user_id: "U123", recipient_team_id: "T123",
      task_display_mode: Slack::Api::Streaming::TaskDisplayMode::Plan,
      chunks: [Slack::Api::Streaming::MarkdownTextChunk.new("Checking the report.")]))
    output.puts "Started stream #{stream.ts} in #{stream.channel}"

    source = Slack::UI::BlockElements::UrlSource.new(url: "https://example.com/q3", text: "Q3 report")
    stream.append(client, chunks: [
      Slack::Api::Streaming::PlanUpdateChunk.new("Answer the question"),
      Slack::Api::Streaming::TaskUpdateChunk.new(id: "read", title: "Read the report",
        status: Slack::UI::TaskStatus::Complete, sources: [source]),
    ])
    output.puts "Appended the plan"

    final = stream.stop(client, chunks: [Slack::Api::Streaming::MarkdownTextChunk.new("Revenue grew 4%.")],
      blocks: [Slack::UI::Blocks::Section.new(text: Slack::UI.mrkdwn("Was this helpful?"))],
      session_status: Slack::Api::Streaming::SessionStatus::Closed)
    output.puts "Final text: #{final.message.try(&.["text"].as_s)}"
  end
end
