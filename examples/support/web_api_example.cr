require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Sends a typed request and a generic call, then reads a Slack error code.
module OfflineWebApiExample
  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-web-api", transport: OfflineExample::WebMockTransport.new)

    WebMock.stub(:post, "https://slack.com/api/reactions.add")
      .with(body: %({"channel":"C123","name":"eyes","timestamp":"1710000000.000100"}))
      .to_return(body: %({"ok":true}))
    client.call(Slack::Api::ReactionsAdd.new(channel: "C123", name: "eyes", timestamp: "1710000000.000100"))
    output.puts "Added :eyes: to C123"

    WebMock.stub(:post, "https://slack.com/api/emoji.list")
      .with(body: "include_categories=true")
      .to_return(body: %({"ok":true,"emoji":{"shipit":"alias:squirrel"}}))
    emoji = client.call("emoji.list", {include_categories: true})
    output.puts "Custom emoji: #{emoji["emoji"].as_h.keys.join(", ")}"

    WebMock.stub(:post, "https://slack.com/api/chat.delete")
      .to_return(body: %({"ok":false,"error":"message_not_found"}))
    begin
      client.call(Slack::Api::ChatDelete.new(channel: "C123", ts: "1710000000.000100"))
    rescue error : Slack::Api::RateLimited
      output.puts "Retry after #{error.retry_after}"
    rescue error : Slack::Api::Error
      output.puts "Delete failed: #{error.code}"
    end
  end
end
