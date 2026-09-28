require "../../src/slack"
require "../../src/slack/testing"
require "webmock"
require "./webmock_transport"

module OfflineRichTextExample
  alias UI = Slack::UI
  alias RT = UI::RichText
  alias Received = Slack::Interactions::RichText

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      posted = wire
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: {type: "message", ts: "1710000000.000001", blocks: wire["blocks"]}}.to_json)
    end
    message = UI.message(fallback_text: "Release 2.0 is live") do |builder|
      builder.rich_text(block_id: "notes", elements: [
        RT::Section.new(elements: [
          RT::Text.new("Release "), RT::Text.new("2.0", style: RT::TextStyle.new(bold: true, highlight: true)),
          RT::Text.new(" is live for "), RT::Team.new("T-PARTNER"), RT::Text.new(". "), RT::Emoji.new("tada"),
        ] of RT::Element),
        RT::List.new(RT::ListStyle::Bullet, elements: [
          RT::Section.new(elements: {RT::Text.new("Faster builds")}),
          RT::Section.new(elements: {RT::Text.new("New "), RT::Link.new("https://example.com/api", text: "API")}),
          RT::Section.new(elements: {
            RT::Text.new("Rollout: "),
            # A link to one section of a canvas.
            RT::Canvas.new("F-RUNBOOK", section_id: "temp:C:rollout", text: "Release runbook", style: RT::Style.new(underline: true)),
          }),
        ]),
        RT::Preformatted.new(elements: {RT::Text.new("shards update")}, language: "shell"),
      ])
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))

    # An independent, signed message event: a user reply written in Slack's composer.
    body = <<-JSON
      {"token":"synthetic","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC","type":"event_callback","event_id":"Ev-SYNTHETIC","event_time":1710000001,
      "event":{"type":"message","user":"U-READER","team":"T-SYNTHETIC","channel":"C-SYNTHETIC","channel_type":"channel","ts":"1710000001.000002",
      "thread_ts":"1710000000.000001","text":"Thanks <@U-AUTHOR>! Next: docs, changelog","blocks":[
      {"type":"rich_text","block_id":"r3Pl","elements":[
      {"type":"rich_text_section","elements":[{"type":"text","text":"Thanks "},{"type":"user","user_id":"U-AUTHOR"},{"type":"text","text":"! Next:"}]},
      {"type":"rich_text_section","elements":[{"type":"text","text":"Questions? "},{"type":"workflow_mention","workflow_id":"Wf-FEEDBACK",
      "function_trigger_id":"Ft-FEEDBACK","text":"Send feedback","channel_id":"C-SYNTHETIC","ts":"1710000001.000002"}]},
      {"type":"rich_text_list","style":"ordered","indent":0,"border":0,"elements":[
      {"type":"rich_text_section","elements":[{"type":"text","text":"docs"}]},
      {"type":"rich_text_section","elements":[{"type":"text","text":"changelog","style":{"italic":true}}]}]}]}]}}
      JSON
    event = receive(body).event
    raise "Expected a message event" unless event.is_a?(Slack::Events::Message)
    # Malformed blocks raise Slack::Interactions::TypeMismatch with the JSON path.
    event.blocks.each do |reply|
      next unless reply.is_a?(Received::Block)
      output.puts "Mentioned users: #{mentioned_users(reply).join(", ")}"
      output.puts "Follow-up items: #{list_items(reply).join(", ")}"
      output.puts "Workflows offered: #{workflows(reply).join(", ")}"
    end
    body = posted
    raise "chat.postMessage was not called" unless body
    body
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

  def self.workflows(block : Received::Block) : Array(String)
    block.elements.flat_map do |container|
      next [] of String unless container.is_a?(Received::Section)
      container.elements.compact_map do |element|
        "#{element.text} (#{element.function_trigger_id})" if element.is_a?(Received::WorkflowMention)
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
    request = Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: "/events")
    event = Slack::Events.parse(VERIFIER.verify(request).body)
    event.as?(Slack::VerifiedEvent) || raise "Expected an event callback"
  end
end
