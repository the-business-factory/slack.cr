require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineRadioButtonsExample
  alias UI = Slack::UI::Checked

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
    digest = UI::CompositionObjects::RadioOption.new(text: UI.mrkdwn("*Digest*"), value: "digest")
    immediate = UI::CompositionObjects::RadioOption.new(text: UI.plain("Immediate"), value: "immediate")
    control = UI::BlockElements::RadioButtons.new(action_id: "delivery", options: {digest, immediate}, initial_option: digest)
    message = UI.message(fallback_text: "Choose delivery") do |builder|
      builder.section(UI.plain("Delivery"), block_id: "preferences", accessory: control)
    end
    Slack::Api::CheckedChatPostMessage.new(token: "xoxb-synthetic", channel: "C-SYNTHETIC", message: message, transport: OfflineExample::WebMockTransport.new).call

    # Independently authored Slack payloads, not derived from outbound values.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"radio_buttons","block_id":"preferences","action_id":"delivery","selected_option":{"text":{"type":"mrkdwn","text":"*Digest*"},"value":"digest"}}]})
    case interaction = receive(payload)
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::RadioButtonsAction
        selected = action.selected_option || raise "Absent or null selection"
        # Real handlers must acknowledge each interaction within three seconds.
        acknowledgement = HTTP::Client::Response.new(200, body: "")
        output.puts "Selected delivery: #{selected.value} (acknowledged #{acknowledgement.status_code})"
        trigger = interaction.trigger_id || raise "Missing trigger"
        view = UI.form_modal(title: UI.plain("Optional override"), submit: UI.plain("Save")) do |builder|
          builder.input(label: UI.plain("Delivery override"), block_id: "override", optional: true,
            element: UI::BlockElements::RadioButtons.new(options: {digest, immediate}, action_id: "delivery"))
        end
        Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: trigger, view: view, transport: OfflineExample::WebMockTransport.new).call
      else
        raise "Expected radio action"
      end
    else
      raise "Expected block action"
    end

    payload = %({"type":"view_submission","team":null,"view":{"state":{"values":{"override":{"delivery":{"type":"radio_buttons","selected_option":null}}}}}})
    case interaction = receive(payload)
    when Slack::Interactions::ViewSubmission
      state = interaction.state_map.radio_buttons_value?("override", "delivery") || raise "Missing state"
      raise "Expected unselected state" unless state.selected_option_presence.null? && state.selected_option.nil?
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Saved delivery: none (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected submission"
    end
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      control = wire["blocks"][0]["accessory"]
      raise "Missing radio buttons" unless control["type"].as_s == "radio_buttons"
      raise "Missing initial selection" unless control["initial_option"]["value"].as_s == "digest"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: wire}.to_json)
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      input = wire["view"]["blocks"][0]
      raise "Expected optional radio input" unless input["optional"].as_bool && input["element"]["type"].as_s == "radio_buttons"
      raise "Expected no initial selection" if input["element"]["initial_option"]?
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
