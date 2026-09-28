require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineConversationsSelectExample
  alias UI = Slack::UI

  def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    Slack.process_interaction(HTTP::Request.new("POST", "/interactions", headers, body))
  end

  def self.run(output : IO = STDOUT) : Nil
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    install_transport
    message = UI.message(fallback_text: "Choose notification conversations") do |builder|
      builder.section(UI.plain("Notification conversation"), block_id: "notifications",
        accessory: UI::BlockElements::ConversationsSelect.new(action_id: "notification", initial_conversation: "D-NOTIFY",
          filter: UI::CompositionObjects::ConversationFilter.new(include: {"public", "private", "im"}, exclude_bot_users: true)))
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))

    # Independently authored Slack payloads, not derived from outbound values.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"conversations_select","block_id":"notifications","action_id":"notification","selected_conversation":"D-NOTIFY"}]})
    case interaction = receive(payload)
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::ConversationsSelectAction
        notification = action.selected_conversation || raise "Absent or null notification"
        # Real handlers must acknowledge each interaction within three seconds.
        acknowledgement = HTTP::Client::Response.new(200, body: "")
        output.puts "Selected notification conversation: #{notification} (acknowledged #{acknowledgement.status_code})"
        trigger = interaction.trigger_id || raise "Missing trigger"
        view = UI.form_modal(title: UI.plain("Destinations"), submit: UI.plain("Save"),
          private_metadata: notification) do |builder|
          builder.input(label: UI.plain("Destinations"), block_id: "destinations", optional: true,
            element: UI::BlockElements::MultiConversationsSelect.new(action_id: "destinations",
              initial_conversations: {notification}, max_selected_items: 3,
              default_to_current_conversation: false,
              filter: UI::CompositionObjects::ConversationFilter.new(exclude_external_shared_channels: true)))
        end
        client.call(Slack::Api::ViewsOpen.new(trigger_id: trigger, view: view))
      else
        raise "Expected notification selection"
      end
    else
      raise "Expected block action"
    end

    payload = %({"type":"view_submission","team":null,"view":{"private_metadata":"D-NOTIFY","state":{"values":{"destinations":{"destinations":{"type":"multi_conversations_select","selected_conversations":["C-ONE","G-TWO"]}}}}}})
    case interaction = receive(payload)
    when Slack::Interactions::ViewSubmission
      state = interaction.state_map.multi_conversations_select_value?("destinations", "destinations") || raise "Missing destination state"
      destinations = state.selected_conversations || raise "Absent or null destinations"
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
      raise "Missing notification select" unless control["type"].as_s == "conversations_select"
      raise "Missing conversation filter" unless control["filter"] == JSON.parse(%({"include":["public","private","im"],"exclude_bot_users":true}))
      raise "Missing initial notification" unless control["initial_conversation"].as_s == "D-NOTIFY"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: {type: "message", ts: "1710000000.000001", blocks: wire["blocks"]}}.to_json)
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      input = wire["view"]["blocks"][0]
      control = input["element"]
      raise "Expected optional destinations" unless input["optional"].as_bool && control["type"].as_s == "multi_conversations_select"
      raise "Missing initial destination" unless control["initial_conversations"].as_a.map(&.as_s) == ["D-NOTIFY"]
      raise "Missing default setting" unless control["default_to_current_conversation"].as_bool == false
      raise "Missing destination filter" unless control["filter"] == JSON.parse(%({"exclude_external_shared_channels":true}))
      raise "Missing destination limit" unless control["max_selected_items"].as_i == 3
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
