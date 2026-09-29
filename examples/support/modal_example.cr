require "../../src/slack"
require "../../src/slack/testing"
require "webmock"
require "./webmock_transport"

module OfflineModalExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    request = Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: "/interactions", content_type: "application/x-www-form-urlencoded")
    Slack::Interactions.parse(VERIFIER.verify(request).body)
  end

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message body")
      raise "Incorrect message action" unless wire["blocks"][0]["elements"][0]["action_id"].as_s == "request.open"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: {type: "message", ts: "1710000000.000001", blocks: wire["blocks"]}}.to_json)
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
    client = Slack::Api::Client.new(token: "xoxb-synthetic-message", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))

    # Simulate Slack returning the IDs and value from the posted button.
    button = JSON.parse(message.to_json)["blocks"][0]["elements"][0]
    interaction = receive({type: "block_actions", trigger_id: "synthetic-trigger", team: {id: "T-SYNTHETIC"},
                           user: {id: "U-SYNTHETIC"}, api_app_id: "A-SYNTHETIC",
                           container: {type: "message", channel_id: "C-SYNTHETIC", message_ts: "1710000000.000001"},
                           actions: [{type: "button", block_id: "request.actions", action_id: button["action_id"], value: button["value"]}]}.to_json)
    case interaction
    when Slack::Interactions::BlockAction
      case action = interaction.actions.first
      when Slack::Interactions::ButtonAction
        raise "Unexpected action" unless action.action_id == "request.open"
        trigger = interaction.trigger_id || raise "Missing trigger ID"
        view = UI.form_modal(title: UI.plain("Request reason"), submit: UI.plain("Save"),
          callback_id: "request.reason", external_id: "request-42", private_metadata: action.value) do |builder|
          builder.section(UI.mrkdwn("Why do you need this request?"))
          builder.input(label: UI.plain("Reason"), block_id: "request.reason", optional: true,
            element: UI::BlockElements::PlainTextInput.new(action_id: "reason", multiline: true, max_length: 3000))
        end
        client = Slack::Api::Client.new(token: "xoxb-synthetic-modal", transport: OfflineExample::WebMockTransport.new)
        opened = client.call(Slack::Api::ViewsOpen.new(trigger_id: trigger, view: view))
        submit(opened.view, output)
      else
        raise "Expected button action"
      end
    else
      raise "Expected block action"
    end
  end

  def self.submit(opened_view : JSON::Any, output : IO) : Nil
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
      output.puts "Saved request 42: #{reason} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected view submission"
    end
  end
end
