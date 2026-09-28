require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineVideoExample
  alias UI = Slack::UI

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      expected = JSON.parse(<<-JSON)
        {"channel":"C123","text":"Release 4.2 walkthrough video","blocks":[
          {"type":"section","text":{"type":"mrkdwn","text":"*Release 4.2* is live."}},
          {"type":"video","block_id":"release.video","alt_text":"Release 4.2 walkthrough",
           "title":{"type":"plain_text","text":"Release 4.2 walkthrough"},
           "title_url":"https://videos.example.test/watch/release-4-2",
           "description":{"type":"plain_text","text":"Five minutes on what changed."},
           "thumbnail_url":"https://videos.example.test/thumbs/release-4-2.jpg",
           "video_url":"https://videos.example.test/embed/release-4-2",
           "provider_name":"Example Video"}]}
        JSON
      raise "Incorrect video message" unless JSON.parse(request.body || raise "Missing posted message") == expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C123","ts":"1710000000.000100","message":{"text":"Release 4.2 walkthrough video"}}))
    end

    # Slack embeds video_url in an iframe. The app needs links.embed:write and
    # the URL domain in its unfurl domains; Slack checks those remotely.
    message = UI.message(fallback_text: "Release 4.2 walkthrough video") do |builder|
      builder.section(UI.mrkdwn("*Release 4.2* is live."))
      builder.video(
        alt_text: "Release 4.2 walkthrough", title: UI.plain("Release 4.2 walkthrough"),
        title_url: "https://videos.example.test/watch/release-4-2",
        description: UI.plain("Five minutes on what changed."),
        thumbnail_url: "https://videos.example.test/thumbs/release-4-2.jpg",
        video_url: "https://videos.example.test/embed/release-4-2",
        provider_name: "Example Video", block_id: "release.video")
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic-video", transport: OfflineExample::WebMockTransport.new)
    posted = client.call(Slack::Api::ChatPostMessage.new(channel: "C123", message: message))
    output.puts "Posted video message #{posted.channel}/#{posted.ts}"

    begin
      UI::Blocks::Video.new(alt_text: "Draft", title: UI.plain("Draft"),
        thumbnail_url: "https://videos.example.test/thumbs/draft.jpg",
        video_url: "http://videos.example.test/embed/draft")
    rescue error : UI::ValidationError
      output.puts "Rejected before sending: #{error.issues.map(&.code).join(", ")}"
    end
  end
end
