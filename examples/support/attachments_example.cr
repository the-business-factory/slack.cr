require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Posts a deploy summary with a colored attachment, metadata, and an emoji icon.
module OfflineAttachmentsExample
  alias UI = Slack::UI

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-attachments", transport: OfflineExample::WebMockTransport.new)
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      output.puts request.body
      HTTP::Client::Response.new(200, body: <<-JSON)
        {"ok":true,"channel":"C123","ts":"1710000123.000200",
         "message":{"type":"message","subtype":"bot_message","ts":"1710000123.000200","text":"Deploy 812 finished",
         "bot_id":"B123","metadata":{"event_type":"deploy_finished","event_payload":{"deploy_id":"812"}}}}
        JSON
    end

    message = UI.message(fallback_text: "Deploy 812 finished") do |builder|
      builder.section(UI.mrkdwn("*Deploy 812* finished"))
    end
    checks = UI::Attachment.new(
      color: UI::Attachment::Color.hex("#2EB886"),
      blocks: [UI::Blocks::Context.new(elements: [UI.mrkdwn("api: healthy · web: healthy")])]
    )
    request = Slack::Api::ChatPostMessage.new(
      channel: "C123",
      message: message,
      attachments: [checks],
      metadata: UI::MessageMetadata.new(event_type: "deploy_finished",
        event_payload: {"deploy_id" => JSON::Any.new("812")}),
      icon: UI::Icon::Emoji.new(":rocket:")
    )

    posted = client.call(request).message
    output.puts "Posted #{posted.ts} with metadata #{posted.metadata.try(&.["event_type"])}"
  end
end
