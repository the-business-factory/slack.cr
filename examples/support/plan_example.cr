require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Streams a plan in a direct message: start in plan mode, append task updates,
# and stop with a final Plan block that keeps the finished tasks in the message.
module OfflinePlanExample
  STREAM = %({"ok":true,"channel":"D123","ts":"1721609700.000200"})

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-plan", transport: OfflineExample::WebMockTransport.new)
    WebMock.stub(:post, "https://slack.com/api/chat.startStream")
      .with(body: %({"channel":"D123","task_display_mode":"plan","chunks":[{"type":"plan_update","title":"Check the deploy"}]}))
      .to_return(body: STREAM)
    WebMock.stub(:post, "https://slack.com/api/chat.appendStream")
      .with(body: %({"channel":"D123","ts":"1721609700.000200","chunks":[{"type":"task_update","id":"build","title":"Read the build log","status":"complete"},{"type":"task_update","id":"smoke","title":"Run the smoke tests","status":"in_progress"}]}))
      .to_return(body: STREAM)
    WebMock.stub(:post, "https://slack.com/api/chat.appendStream")
      .with(body: %({"channel":"D123","ts":"1721609700.000200","chunks":[{"type":"task_update","id":"smoke","title":"Run the smoke tests","status":"complete","output":"12 checks passed"}]}))
      .to_return(body: STREAM)
    WebMock.stub(:post, "https://slack.com/api/chat.stopStream")
      .with(body: %({"channel":"D123","ts":"1721609700.000200","chunks":[{"type":"markdown_text","text":"The deploy is healthy."}],"blocks":[{"type":"plan","title":"Check the deploy","tasks":[{"type":"task_card","task_id":"build","title":"Read the build log","status":"complete","sources":[{"type":"url","url":"https://ci.example.com/builds/812","text":"Build 812"}]},{"type":"task_card","task_id":"smoke","title":"Run the smoke tests","status":"complete","output":{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"12 checks passed"}]}]}}],"block_id":"deploy.plan"}],"session_status":"closed"}))
      .to_return(body: %({"ok":true,"channel":"D123","ts":"1721609700.000200","message":{"type":"message","text":"The deploy is healthy."}}))

    stream = client.start_stream(Slack::Api::ChatStartStream.new(
      channel: "D123", task_display_mode: Slack::Api::Streaming::TaskDisplayMode::Plan,
      chunks: [Slack::Api::Streaming::PlanUpdateChunk.new("Check the deploy")]))
    output.puts "Started plan #{stream.ts}"

    stream.append(client, chunks: [
      task_update("build", "Read the build log", Slack::UI::TaskStatus::Complete),
      task_update("smoke", "Run the smoke tests", Slack::UI::TaskStatus::InProgress),
    ])
    stream.append(client, chunks: [task_update("smoke", "Run the smoke tests", Slack::UI::TaskStatus::Complete, "12 checks passed")])
    output.puts "Updated 2 tasks"

    final = stream.stop(client, chunks: [Slack::Api::Streaming::MarkdownTextChunk.new("The deploy is healthy.")],
      blocks: [final_plan], session_status: Slack::Api::Streaming::SessionStatus::Closed)
    output.puts "Final text: #{final.message.try(&.["text"].as_s)}"
  end

  private def self.task_update(id : String, title : String, status : Slack::UI::TaskStatus,
                               task_output : String? = nil) : Slack::Api::Streaming::TaskUpdateChunk
    Slack::Api::Streaming::TaskUpdateChunk.new(id: id, title: title, status: status, output: task_output)
  end

  private def self.final_plan : Slack::UI::Blocks::Plan
    build_log = Slack::UI::BlockElements::UrlSource.new(url: "https://ci.example.com/builds/812", text: "Build 812")
    checks = Slack::UI::Blocks::RichText.new(elements: {
      Slack::UI::RichText::Section.new(elements: {Slack::UI::RichText::Text.new("12 checks passed")}),
    })
    Slack::UI::Blocks::Plan.new(title: "Check the deploy", block_id: "deploy.plan", tasks: {
      Slack::UI::Blocks::TaskCard.new(task_id: "build", title: "Read the build log",
        status: Slack::UI::TaskStatus::Complete, sources: [build_log]),
      Slack::UI::Blocks::TaskCard.new(task_id: "smoke", title: "Run the smoke tests",
        status: Slack::UI::TaskStatus::Complete, output: checks),
    })
  end
end
