require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Posts an assistant reply that is already standard markdown, such as LLM
# output. Slack translates the markdown block into its own blocks.
module OfflineMarkdownExample
  alias UI = Slack::UI

  ANSWER = <<-MARKDOWN
    ## Rotate the signing secret

    1. Open **Basic Information**.
    2. Select _Regenerate_ next to the secret.
    3. Update `SLACK_SIGNING_SECRET` and redeploy.

    See [Verifying requests](https://docs.slack.dev/authentication/verifying-requests-from-slack).
    MARKDOWN

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted = JSON.parse(request.body || raise "Missing posted message")
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000400","message":{"type":"message","ts":"1710000000.000400","text":"How to rotate the signing secret"}}))
    end

    message = UI.message(fallback_text: "How to rotate the signing secret") do |builder|
      builder.markdown(ANSWER)
      builder.context({UI.plain("Generated answer. Check the steps before you use them.")})
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic-markdown", transport: OfflineExample::WebMockTransport.new)
    result = client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))
    output.puts "Posted answer to #{result.channel}/#{result.ts}"

    # Each block is valid, but together they exceed Slack's 12,000-character
    # limit for the markdown blocks in one message. Send long answers as
    # separate messages.
    begin
      UI.message(fallback_text: "Long answer") do |builder|
        2.times { builder.markdown("x" * 7_000) }
      end
    rescue error : UI::ValidationError
      output.puts "Rejected before sending: #{error.issues.map(&.code).join(", ")}"
    end
    body = posted
    raise "chat.postMessage was not called" unless body
    body
  end
end
