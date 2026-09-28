require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineOverflowExample
  alias UI = Slack::UI

  def self.run(output : IO = STDOUT) : Nil
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      raise "Missing overflow menu" unless wire["blocks"][0]["accessory"]["type"].as_s == "overflow"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: {type: "message", ts: "1710000000.000001", blocks: wire["blocks"]}}.to_json)
    end
    menu = UI::BlockElements::Overflow.new(action_id: "request.more", options: {
      UI::CompositionObjects::OverflowOption.new(text: UI.plain("Archive"), value: "archive"),
      UI::CompositionObjects::OverflowOption.new(text: UI.plain("Details"), value: "details", url: "https://example.com/requests/42"),
    })
    message = UI.message(fallback_text: "Request 42 actions") do |builder|
      builder.section(UI.plain("Request 42"), block_id: "request", accessory: menu)
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))

    # Simulate an independently authored Slack URL-option click.
    payload = %({"type":"block_actions","team":null,"actions":[{"type":"overflow","block_id":"request","action_id":"request.more","selected_option":{"text":{"type":"plain_text","text":"Details"},"value":"details"}}]})
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    case interaction = Slack.process_interaction(HTTP::Request.new("POST", "/interactions", headers, body))
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::OverflowAction
        # URL options also send interactions. Real handlers must acknowledge
        # within three seconds, even when the browser opens a link.
        acknowledgement = HTTP::Client::Response.new(200, body: "")
        output.puts "Selected request action: #{action.selected_option.value} (acknowledged #{acknowledgement.status_code})"
      else
        raise "Expected overflow action"
      end
    else
      raise "Expected block action"
    end
  end
end
