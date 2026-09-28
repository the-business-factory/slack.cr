require "../../src/slack"
require "../../src/slack/testing"
require "webmock"
require "./webmock_transport"

module OfflineChannelsSelectExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    request = Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: "/interactions", content_type: "application/x-www-form-urlencoded")
    Slack::Interactions.parse(VERIFIER.verify(request).body)
  end

  def self.run(output : IO = STDOUT) : Nil
    install_transport
    message = UI.message(fallback_text: "Choose notification channels") do |builder|
      builder.section(UI.plain("Notification channel"), block_id: "notifications",
        accessory: UI::BlockElements::ChannelsSelect.new(action_id: "notification", initial_channel: "C-NOTIFY"))
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))

    # Independently authored Slack payloads, not derived from outbound values.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"channels_select","block_id":"notifications","action_id":"notification","selected_channel":"C-NOTIFY"}]})
    case interaction = receive(payload)
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::ChannelsSelectAction
        notification = action.selected_channel || raise "Absent or null notification"
        # Real handlers must acknowledge each interaction within three seconds.
        acknowledgement = HTTP::Client::Response.new(200, body: "")
        output.puts "Selected notification channel: #{notification} (acknowledged #{acknowledgement.status_code})"
        trigger = interaction.trigger_id || raise "Missing trigger"
        view = UI.form_modal(title: UI.plain("Destinations"), submit: UI.plain("Save"),
          private_metadata: notification) do |builder|
          builder.input(label: UI.plain("Destinations"), block_id: "destinations", optional: true,
            element: UI::BlockElements::MultiChannelsSelect.new(action_id: "destinations",
              initial_channels: {notification}, max_selected_items: 3))
        end
        client.call(Slack::Api::ViewsOpen.new(trigger_id: trigger, view: view))
      else
        raise "Expected notification selection"
      end
    else
      raise "Expected block action"
    end

    payload = %({"type":"view_submission","team":null,"view":{"private_metadata":"C-NOTIFY","state":{"values":{"destinations":{"destinations":{"type":"multi_channels_select","selected_channels":["C-ONE","C-TWO"]}}}}}})
    case interaction = receive(payload)
    when Slack::Interactions::ViewSubmission
      state = interaction.state_map.multi_channels_select_value?("destinations", "destinations") || raise "Missing destination state"
      destinations = state.selected_channels || raise "Absent or null destinations"
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Saved destinations: #{destinations.join(", ")} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected submission"
    end
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      control = wire["blocks"][0]["accessory"]
      raise "Missing notification select" unless control["type"].as_s == "channels_select"
      raise "Missing initial notification" unless control["initial_channel"].as_s == "C-NOTIFY"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: {type: "message", ts: "1710000000.000001", blocks: wire["blocks"]}}.to_json)
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      input = wire["view"]["blocks"][0]
      control = input["element"]
      raise "Expected optional destinations" unless input["optional"].as_bool && control["type"].as_s == "multi_channels_select"
      raise "Missing initial destination" unless control["initial_channels"].as_a.map(&.as_s) == ["C-NOTIFY"]
      raise "Missing destination limit" unless control["max_selected_items"].as_i == 3
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
