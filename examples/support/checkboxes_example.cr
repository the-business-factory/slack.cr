require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineCheckboxesExample
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
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      control = wire["blocks"][0]["accessory"]
      raise "Missing checkboxes" unless control["type"].as_s == "checkboxes"
      raise "Missing initial selection" unless control["initial_options"][0]["value"].as_s == "digest"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: {type: "message", ts: "1710000000.000001", blocks: wire["blocks"]}}.to_json)
    end
    digest = UI::CompositionObjects::CheckboxOption.new(text: UI.mrkdwn("*Daily digest*"), value: "digest")
    alerts = UI::CompositionObjects::CheckboxOption.new(text: UI.plain("Alerts"), value: "alerts")
    control = UI::BlockElements::Checkboxes.new(action_id: "notifications", options: {digest, alerts}, initial_options: {digest})
    message = UI.message(fallback_text: "Choose notifications") do |builder|
      builder.section(UI.plain("Notifications"), block_id: "preferences", accessory: control)
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))

    # Independently authored Slack payloads exercise both selecting and clearing.
    payload = %({"type":"block_actions","team":null,"actions":[{"type":"checkboxes","block_id":"preferences","action_id":"notifications","selected_options":[{"text":{"type":"mrkdwn","text":"*Daily digest*"},"value":"digest"}]}]})
    case interaction = receive(payload)
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::CheckboxesAction
        selected = action.selected_options || raise "Absent or null selection"
        # Real handlers must acknowledge each interaction within three seconds.
        acknowledgement = HTTP::Client::Response.new(200, body: "")
        output.puts "Selected notifications: #{selected.map(&.value).join(", ")} (acknowledged #{acknowledgement.status_code})"
      else
        raise "Expected checkbox action"
      end
    else
      raise "Expected block action"
    end

    payload = %({"type":"view_submission","team":null,"view":{"state":{"values":{"preferences":{"notifications":{"type":"checkboxes","selected_options":[]}}}}}})
    case interaction = receive(payload)
    when Slack::Interactions::ViewSubmission
      state = interaction.state_map.checkboxes_value?("preferences", "notifications") || raise "Missing state"
      selected = state.selected_options || raise "Absent or null selection"
      raise "Expected cleared selections" unless selected.empty?
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Saved notifications: none (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected submission"
    end
  end
end
