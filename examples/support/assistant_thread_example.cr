require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Prepares an app thread: suggested prompts, a title, and a loading status, then clears the status.
module OfflineAssistantThreadExample
  THREAD = {channel_id: "D123", thread_ts: "1724264405.531769"}

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-assistant", transport: OfflineExample::WebMockTransport.new)
    WebMock.stub(:post, "https://slack.com/api/assistant.threads.setSuggestedPrompts")
      .with(body: %({"channel_id":"D123","title":"Try one of these","prompts":[{"title":"Summarize","message":"Summarize this channel."},{"title":"Draft","message":"Draft a status update."}]}))
      .to_return(body: %({"ok":true}))
    WebMock.stub(:post, "https://slack.com/api/assistant.threads.setTitle")
      .with(body: %({"channel_id":"D123","thread_ts":"1724264405.531769","title":"Weekly summary"}))
      .to_return(body: %({"ok":true}))
    WebMock.stub(:post, "https://slack.com/api/assistant.threads.setStatus")
      .with(body: %({"channel_id":"D123","thread_ts":"1724264405.531769","status":"is thinking...","loading_messages":["Reading the channel","Writing the summary"]}))
      .to_return(body: %({"ok":true}))
    WebMock.stub(:post, "https://slack.com/api/assistant.threads.setStatus")
      .with(body: %({"channel_id":"D123","thread_ts":"1724264405.531769","status":""}))
      .to_return(body: %({"ok":true}))

    client.call(Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: THREAD[:channel_id],
      title: "Try one of these", prompts: [
      Slack::Api::SuggestedPrompt.new(title: "Summarize", message: "Summarize this channel."),
      Slack::Api::SuggestedPrompt.new(title: "Draft", message: "Draft a status update."),
    ]))
    output.puts "Suggested 2 prompts"

    client.call(Slack::Api::AssistantThreadsSetTitle.new(**THREAD, title: "Weekly summary"))
    output.puts "Titled the thread"

    client.call(Slack::Api::AssistantThreadsSetStatus.new(**THREAD, status: "is thinking...",
      loading_messages: ["Reading the channel", "Writing the summary"]))
    output.puts "Showing a status"

    client.call(Slack::Api::AssistantThreadsSetStatus.new(**THREAD, status: ""))
    output.puts "Cleared the status"
  end
end
