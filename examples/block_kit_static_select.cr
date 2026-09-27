# Run with: crystal run examples/block_kit_static_select.cr
# All HTTP uses WebMock and synthetic credentials.
require "../src/slack"
require "webmock"
require "./support/webmock_transport"

module OfflineStaticSelectExample
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

  def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      raise "Missing static select" unless wire["blocks"][0]["accessory"]["type"].as_s == "static_select"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: wire}.to_json)
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing view")
      raise "Missing multi select" unless wire["view"]["blocks"][0]["element"]["type"].as_s == "multi_static_select"
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end

  def self.run : Nil
    Slack.configure do |settings|
      settings.client_id = "synthetic-client"
      settings.client_secret = "synthetic-client-secret"
      settings.signing_secret = "synthetic-signing-secret"
    end
    install_transport
    red = UI::CompositionObjects::Option.new(text: UI.plain("Red"), value: "red")
    blue = UI::CompositionObjects::Option.new(text: UI.plain("Blue"), value: "blue")
    options = {red, blue}
    single = UI::BlockElements::StaticSelect.new(options: options, action_id: "color", placeholder: UI.plain("Choose a color"))
    message = UI.message(fallback_text: "Choose a color, then choose your notification colors.") do |builder|
      builder.section(UI.plain("Your color"), block_id: "preferences", accessory: single)
    end
    Slack::Api::CheckedChatPostMessage.new(token: "xoxb-synthetic", channel: "C-SYNTHETIC", message: message, transport: OfflineExample::WebMockTransport.new).call

    # Simulate a signed Slack selection using the option sent above.
    interaction = receive({type: "block_actions", team: nil, trigger_id: "synthetic-trigger",
                           actions: [{type: "static_select", block_id: "preferences", action_id: "color", selected_option: red}]}.to_json)
    case interaction
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::StaticSelectAction
        raise "Unexpected color" unless action.selected_option.try(&.value) == "red"
        trigger = interaction.trigger_id || raise "Missing trigger"
        group = UI::CompositionObjects::OptionGroup.new(label: UI.plain("Colors"), options: options)
        view = UI.form_modal(title: UI.plain("Notification colors"), submit: UI.plain("Save")) do |builder|
          builder.input(label: UI.plain("Notify for colors"), block_id: "notifications", optional: true,
            element: UI::BlockElements::MultiStaticSelect.new(option_groups: {group}, action_id: "colors",
              initial_options: {red}, max_selected_items: 2, focus_on_load: true))
        end
        opened = Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: trigger, view: view, transport: OfflineExample::WebMockTransport.new).call
        submit(opened.view)
      else
        raise "Expected static select action"
      end
    else
      raise "Expected block action"
    end
  end

  def self.submit(view : JSON::Any) : Nil
    input = view["blocks"][0]
    block_id = input["block_id"].as_s
    action_id = input["element"]["action_id"].as_s
    selections = input["element"]["option_groups"][0]["options"]
    submitted = view.as_h.dup
    submitted["state"] = JSON.parse({values: {block_id => {action_id => {type: "multi_static_select", selected_options: selections}}}}.to_json)
    interaction = receive({type: "view_submission", team: nil, view: submitted}.to_json)
    case interaction
    when Slack::Interactions::ViewSubmission
      entry = interaction.state_map.multi_static_select_value?("notifications", "colors") || raise "Missing state"
      selected = entry.selected_options || raise "Absent or null selection"
      raise "Incorrect selection" unless selected.map(&.value) == ["red", "blue"]
      # Real handlers must acknowledge each action and submission within three
      # seconds. An empty HTTP 200 acknowledges a successful interaction.
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      puts "Saved notification colors: #{selected.map(&.value).join(", ")} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected submission"
    end
  end
end

OfflineStaticSelectExample.run
