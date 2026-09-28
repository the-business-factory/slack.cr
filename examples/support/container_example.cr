require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Groups a bulk update in a collapsible container, posts it, and reads a signed
# click on a button inside the container. Slack sends the click as an ordinary
# block_actions payload; the container itself sends no payload.
module OfflineContainerExample
  alias UI = Slack::UI

  record Change, key : String, from : String, to : String

  CHANGES = [Change.new("DCW-1024", "Open", "Closed"), Change.new("DCW-1025", "In Progress", "Closed")]

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    Slack.configure(&.signing_secret=("synthetic-signing-secret"))
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted = JSON.parse(request.body || raise "Missing posted message")
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000400","message":{"text":"Bulk update"}}))
    end

    message = UI.message(fallback_text: "Bulk update: #{CHANGES.size} records selected") do |builder|
      builder.add(bulk_update(CHANGES))
    end
    Slack::Api::ChatPostMessage.new(token: "xoxb-synthetic-container", channel: "C-SYNTHETIC",
      message: message, transport: OfflineExample::WebMockTransport.new).call

    # Authored from Slack's block_actions reference: the click names the child block.
    interaction = receive(<<-JSON)
      {"type":"block_actions","trigger_id":"synthetic-trigger","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-SYNTHETIC"},
       "api_app_id":"A-SYNTHETIC","container":{"type":"message","channel_id":"C-SYNTHETIC","message_ts":"1710000000.000400"},
       "actions":[{"type":"button","block_id":"bulk.actions","action_id":"bulk.confirm","value":"DCW-1024,DCW-1025",
                   "text":{"type":"plain_text","text":"Confirm all"},"action_ts":"1710000001.000100"}]}
      JSON
    if interaction.is_a?(Slack::Interactions::BlockAction) && (action = interaction.decoded_actions.first).is_a?(Slack::Interactions::ButtonAction)
      output.puts "#{action.action_id} in #{action.block_id}: #{action.value}"
    end

    body = posted
    raise "chat.postMessage was not called" unless body
    body
  end

  def self.bulk_update(changes : Array(Change)) : UI::Blocks::Container
    children = [] of UI::Blocks::Container::Child
    changes.each_with_index do |change, index|
      children << UI::Blocks::Divider.new unless index.zero?
      children << UI::Blocks::Section.new(text: UI.mrkdwn("*#{change.key}*\nStatus: #{change.from} → #{change.to}"), block_id: "record.#{change.key}")
    end
    keys = changes.join(",", &.key)
    children << UI::Blocks::Actions.new(block_id: "bulk.actions", elements: {
      UI::BlockElements::Button.new(text: UI.plain("Confirm all"), action_id: "bulk.confirm", value: keys, style: UI::BlockElements::ButtonStyle::Primary),
      UI::BlockElements::Button.new(text: UI.plain("Cancel"), action_id: "bulk.cancel"),
    })
    UI::Blocks::Container.new(
      title: UI.plain("Bulk update: #{changes.size} records selected"),
      subtitle: UI.plain("Review changes before confirming"),
      is_collapsible: true, block_id: "bulk.update", child_blocks: children
    )
  end

  private def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    Slack.process_interaction(HTTP::Request.new("POST", "/interactions", headers, body))
  end
end
