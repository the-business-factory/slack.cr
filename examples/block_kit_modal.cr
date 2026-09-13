# Run with: crystal run examples/block_kit_modal.cr
# WebMock intercepts every HTTP request. No Slack account or credentials needed.
require "../src/slack"
require "webmock"

module OfflineModalExample
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

  def self.run : Nil
    Slack.configure do |settings|
      settings.client_id = "synthetic-client"
      settings.client_secret = "synthetic-client-secret"
      settings.signing_secret = "synthetic-signing-secret"
    end
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message body")
      raise "Incorrect message action" unless wire["blocks"][0]["elements"][0]["action_id"].as_s == "request.open"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: wire}.to_json)
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing modal body")
      raise "External ID is misplaced" if wire.as_h.has_key?("external_id")
      raise "Incorrect modal" unless wire["view"]["external_id"].as_s == "request-42"
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end

    message = UI.message(fallback_text: "Add a reason for request 42.") do |builder|
      builder.actions(block_id: "request.actions", elements: [UI::BlockElements::Button.new(
        text: UI.plain("Add reason"), action_id: "request.open", value: "42"
      )])
    end
    Slack::Api::CheckedChatPostMessage.new(token: "xoxb-synthetic-message", channel: "C-SYNTHETIC", message: message).call

    # Simulate Slack returning the IDs and value from the posted button.
    button = JSON.parse(message.to_json)["blocks"][0]["elements"][0]
    interaction = receive({type: "block_actions", trigger_id: "synthetic-trigger", team: {id: "T-SYNTHETIC"},
                           user: {id: "U-SYNTHETIC"}, api_app_id: "A-SYNTHETIC",
                           container: {type: "message", channel_id: "C-SYNTHETIC", message_ts: "1710000000.000001"},
                           actions: [{type: "button", block_id: "request.actions", action_id: button["action_id"], value: button["value"]}]}.to_json)
    case interaction
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::ButtonAction
        raise "Unexpected action" unless action.action_id == "request.open"
        trigger = interaction.trigger_id || raise "Missing trigger ID"
        view = UI.form_modal(title: UI.plain("Request reason"), submit: UI.plain("Save"),
          callback_id: "request.reason", external_id: "request-42", private_metadata: action.value) do |builder|
          builder.section(UI.mrkdwn("Why do you need this request?"))
          builder.input(label: UI.plain("Reason"), block_id: "request.reason", optional: true,
            element: UI::BlockElements::PlainTextInput.new(action_id: "reason", multiline: true, max_length: 3000))
        end
        opened = Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic-modal", trigger_id: trigger, view: view).call
        submit(opened.view)
      else
        raise "Expected button action"
      end
    else
      raise "Expected block action"
    end
  end

  def self.submit(opened_view : JSON::Any) : Nil
    input = opened_view["blocks"][1]
    block_id = input["block_id"].as_s
    action_id = input["element"]["action_id"].as_s
    submitted_view = opened_view.as_h.dup
    submitted_view["state"] = JSON.parse({values: {block_id => {action_id => {type: "plain_text_input", value: "Need a test environment."}}}}.to_json)
    interaction = receive({type: "view_submission", team: {id: "T-SYNTHETIC"}, user: {id: "U-SYNTHETIC"},
                           api_app_id: "A-SYNTHETIC", view: submitted_view}.to_json)
    case interaction
    when Slack::Interactions::ViewSubmission
      reason = interaction.plain_text?("request.reason", "reason")
      raise "Incorrect submitted reason" unless reason == "Need a test environment."
      # In a real HTTP handler, acknowledge each valid interaction within three
      # seconds. An empty HTTP 200 response acknowledges this successful submit.
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      puts "Saved request 42: #{reason} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected view submission"
    end
  end
end

OfflineModalExample.run
