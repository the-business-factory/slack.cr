require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineRichTextExample
  alias UI = Slack::UI::Checked
  alias RT = UI::RichText
  alias Received = Slack::Interactions::RichText

  def self.run(output : IO = STDOUT) : Nil
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    install_transport
    message = UI.message(fallback_text: "Release 2.0 is live") do |builder|
      builder.rich_text(block_id: "notes", elements: [
        RT::Section.new(elements: [
          RT::Text.new("Release "), RT::Text.new("2.0", style: RT::TextStyle.new(bold: true)),
          RT::Text.new(" is live. "), RT::Emoji.new("tada"),
        ] of RT::Element),
        RT::List.new(RT::ListStyle::Bullet, elements: [
          RT::Section.new(elements: {RT::Text.new("Faster builds")}),
          RT::Section.new(elements: {RT::Text.new("New "), RT::Link.new("https://example.com/api", text: "API")}),
        ]),
        RT::Preformatted.new(elements: {RT::Text.new("shards update")}, language: "shell"),
      ])
    end
    Slack::Api::CheckedChatPostMessage.new(token: "xoxb-synthetic", channel: "C-SYNTHETIC",
      message: message, transport: OfflineExample::WebMockTransport.new).call

    # An independent, signed message event: a user reply written in Slack's composer.
    body = <<-JSON
      {"token":"synthetic","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC","type":"event_callback","event_id":"Ev-SYNTHETIC","event_time":1710000001,
      "event":{"type":"message","user":"U-READER","team":"T-SYNTHETIC","channel":"C-SYNTHETIC","channel_type":"channel","ts":"1710000001.000002",
      "thread_ts":"1710000000.000001","text":"Thanks <@U-AUTHOR>! Next: docs, changelog","blocks":[
      {"type":"rich_text","block_id":"r3Pl","elements":[
      {"type":"rich_text_section","elements":[{"type":"text","text":"Thanks "},{"type":"user","user_id":"U-AUTHOR"},{"type":"text","text":"! Next:"}]},
      {"type":"rich_text_list","style":"ordered","indent":0,"border":0,"elements":[
      {"type":"rich_text_section","elements":[{"type":"text","text":"docs"}]},
      {"type":"rich_text_section","elements":[{"type":"text","text":"changelog","style":{"italic":true}}]}]}]}]}}
      JSON
    event = receive(body).event
    raise "Expected a message event" unless event.is_a?(Slack::Events::Message)
    event.blocks.each_with_index do |raw, index|
      next unless raw["type"]?.try(&.as_s?) == "rich_text"
      # Malformed trees raise Slack::Interactions::TypeMismatch with this path.
      reply = Received::Block.new(raw, "event.blocks[#{index}]")
      output.puts "Mentioned users: #{mentioned_users(reply).join(", ")}"
      output.puts "Follow-up items: #{list_items(reply).join(", ")}"
    end
  end

  def self.mentioned_users(block : Received::Block) : Array(String)
    block.elements.flat_map do |container|
      case container
      when Received::Section, Received::Quote
        container.elements.compact_map { |element| element.user_id if element.is_a?(Received::User) }
      else
        [] of String
      end
    end
  end

  def self.list_items(block : Received::Block) : Array(String)
    block.elements.flat_map do |container|
      next [] of String unless container.is_a?(Received::List)
      container.elements.map do |item|
        item.elements.compact_map { |element| element.text if element.is_a?(Received::Text) }.join
      end
    end
  end

  private def self.receive(body : String) : Slack::VerifiedEvent
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    event = Slack.process_webhook(HTTP::Request.new("POST", "/events", headers, body))
    event.as?(Slack::VerifiedEvent) || raise "Expected an event callback"
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      notes = wire["blocks"][0]
      raise "Expected rich text" unless notes["type"].as_s == "rich_text"
      raise "Expected a bullet list" unless notes["elements"][1]["style"].as_s == "bullet"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: wire}.to_json)
    end
  end
end
