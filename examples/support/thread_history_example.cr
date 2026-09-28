require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Reads channel history page by page, then reads every reply of one thread.
module OfflineThreadHistoryExample
  CHANNEL = "C123"

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-thread-history",
      transport: OfflineExample::WebMockTransport.new)
    stub_history
    stub_replies

    thread_ts = nil
    client.each_page(Slack::Api::ConversationsHistory.new(CHANNEL, limit: 2)) do |page|
      page.model.messages.each do |message|
        output.puts "#{message.ts} #{message.text}"
        thread_ts ||= message.ts if message.reply_count
      end
    end
    return unless thread_ts

    replies = Slack::Api::ConversationsReplies.new(CHANNEL, thread_ts, limit: 2)
    client.each_page(replies) do |page|
      page.model.messages.each { |reply| output.puts "  #{reply.user}: #{reply.text}" }
    end
  end

  # Slack sends the second page when the request carries the first page's next_cursor.
  private def self.stub_history : Nil
    WebMock.stub(:post, "https://slack.com/api/conversations.history")
      .with(body: "channel=C123&limit=2")
      .to_return(body: <<-JSON)
        {"ok":true,"has_more":true,"pin_count":0,"messages":[
        {"type":"message","user":"U1","text":"Deploy finished","ts":"1710000300.000100"},
        {"type":"message","user":"U2","text":"Deploy started","ts":"1710000200.000100",
        "thread_ts":"1710000200.000100","reply_count":2}],
        "response_metadata":{"next_cursor":"bmV4dF90czoxNzEwMDAwMTAw"}}
        JSON
    WebMock.stub(:post, "https://slack.com/api/conversations.history")
      .with(body: "channel=C123&cursor=bmV4dF90czoxNzEwMDAwMTAw&limit=2")
      .to_return(body: <<-JSON)
        {"ok":true,"has_more":false,"pin_count":0,"messages":[
        {"type":"message","user":"U3","text":"Morning","ts":"1710000100.000100"}],
        "response_metadata":{"next_cursor":""}}
        JSON
  end

  private def self.stub_replies : Nil
    WebMock.stub(:post, "https://slack.com/api/conversations.replies")
      .with(body: "channel=C123&ts=1710000200.000100&limit=2")
      .to_return(body: <<-JSON)
        {"ok":true,"has_more":true,"messages":[
        {"type":"message","user":"U2","text":"Deploy started","ts":"1710000200.000100",
        "thread_ts":"1710000200.000100","reply_count":2},
        {"type":"message","user":"U1","text":"Watching the logs","ts":"1710000210.000100",
        "thread_ts":"1710000200.000100","parent_user_id":"U2"}],
        "response_metadata":{"next_cursor":"dGhyZWFkOjI="}}
        JSON
    WebMock.stub(:post, "https://slack.com/api/conversations.replies")
      .with(body: "channel=C123&ts=1710000200.000100&cursor=dGhyZWFkOjI%3D&limit=2")
      .to_return(body: <<-JSON)
        {"ok":true,"has_more":false,"messages":[
        {"type":"message","user":"U3","text":"All green","ts":"1710000220.000100",
        "thread_ts":"1710000200.000100","parent_user_id":"U2"}]}
        JSON
  end
end
