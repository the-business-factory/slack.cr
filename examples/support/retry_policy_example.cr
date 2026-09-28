require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Posts a digest through a client with a retry policy. Slack answers the first
# post with HTTP 429, so the client waits Retry-After and posts again. The next
# 429 asks for a longer wait than the policy allows, so that call raises.
module OfflineRetryPolicyExample
  TEXT   = "Daily digest: 3 open incidents"
  POSTED = %({"ok":true,"channel":"C123","ts":"1710000000.000200",) +
           %("message":{"type":"message","text":"#{TEXT}","ts":"1710000000.000200"}})

  # *sleep* replaces the wait between attempts; the default sleeps the calling fiber.
  def self.run(output : IO = STDOUT,
               sleep : Proc(Time::Span, Nil) = ->(span : Time::Span) { ::sleep(span); nil }) : Nil
    WebMock.allow_net_connect = false
    stub_post_message([rate_limited("2"), HTTP::Client::Response.new(200, body: POSTED), rate_limited("120")])
    policy = Slack::Api::RetryPolicy.new(max_attempts: 3, max_wait: 30.seconds, sleep: sleep)
    client = Slack::Api::Client.new(token: "xoxb-synthetic-retry",
      transport: OfflineExample::WebMockTransport.new, retry: policy)
    digest = Slack::Api::ChatPostMessage.new(channel: "C123", text: TEXT)

    posted = client.call(digest)
    output.puts "Posted #{posted.ts} to #{posted.channel}"

    begin
      client.call(digest)
    rescue error : Slack::Api::RateLimited
      output.puts "Rate limited; try again in #{error.retry_after.try(&.total_seconds.to_i)} seconds"
    end
  end

  private def self.rate_limited(seconds : String) : HTTP::Client::Response
    HTTP::Client::Response.new(429, headers: HTTP::Headers{"Retry-After" => seconds})
  end

  # Slack answers each post with the next response in *responses*.
  private def self.stub_post_message(responses : Array(HTTP::Client::Response)) : Nil
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .with(body: %({"channel":"C123","text":"#{TEXT}"}))
      .to_return { |_request| responses.shift }
  end
end
