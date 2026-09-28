require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Posts an answer with feedback buttons and a delete button for the asker,
# then reads a signed feedback click and a signed delete click. Slack does not
# document the received action shape for these elements; the typed actions
# follow the Bolt JS types and are not verified against live Slack.
module OfflineContextActionsExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted = JSON.parse(request.body || raise "Missing posted message")
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000400","message":{"type":"message","ts":"1710000000.000400","text":"Answer"}}))
    end

    message = UI.message(fallback_text: "Answer") do |builder|
      builder.section(UI.plain("Rotate the signing secret in the app settings."), block_id: "answer")
      builder.context_actions(answer_actions("U-ASKER"), block_id: "answer.actions")
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic-answer", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))

    output.puts read_click(signed_click(FEEDBACK_CLICK))
    output.puts read_click(signed_click(DELETE_CLICK))
    body = posted
    raise "chat.postMessage was not called" unless body
    body
  end

  def self.answer_actions(asker_id : String) : Array(UI::Blocks::ContextActions::Element)
    confirm = UI::CompositionObjects::Confirmation.new(title: UI.plain("Delete answer?"), text: UI.plain("The answer is removed."),
      confirm: UI.plain("Delete"), deny: UI.plain("Keep"), style: UI::CompositionObjects::ConfirmationStyle::Danger)
    [
      UI::BlockElements::FeedbackButtons.new(action_id: "answer.feedback",
        positive_button: UI::CompositionObjects::FeedbackButton.new(text: UI.plain("Good"), value: "good", accessibility_label: "Mark this answer as good"),
        negative_button: UI::CompositionObjects::FeedbackButton.new(text: UI.plain("Bad"), value: "bad", accessibility_label: "Mark this answer as bad")),
      UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash, text: UI.plain("Delete"),
        action_id: "answer.delete", value: "delete", confirm: confirm, visible_to_user_ids: {asker_id}),
    ] of UI::Blocks::ContextActions::Element
  end

  # Describes a feedback or delete click, or raises for another interaction.
  def self.read_click(request : HTTP::Request) : String
    interaction = Slack::Interactions.parse(VERIFIER.verify(request).body)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)

    case action = interaction.decoded_actions.first
    when Slack::Interactions::FeedbackButtonsAction
      "Feedback: #{action.value || raise "Missing feedback value"}"
    when Slack::Interactions::IconButtonAction
      "Delete requested: #{action.action_id}"
    else
      raise "Expected a feedback or delete click"
    end
  end

  # Simulated clicks. The action fields follow the Bolt JS FeedbackButtonsAction
  # and IconButtonAction types, because Slack's reference does not show them.
  FEEDBACK_CLICK = %({"type":"feedback_buttons","block_id":"answer.actions","action_id":"answer.feedback",) +
                   %("action_ts":"1710000001.000100","value":"bad","text":{"type":"plain_text","text":"Bad"}})
  DELETE_CLICK = %({"type":"icon_button","block_id":"answer.actions","action_id":"answer.delete",) +
                 %("action_ts":"1710000001.000200","icon":"trash","value":"delete","text":{"type":"plain_text","text":"Delete"}})

  def self.signed_click(action : String) : HTTP::Request
    payload = %({"type":"block_actions","team":null,"actions":[#{action}]})
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(SIGNING_SECRET, timestamp, body).compute,
    }
    HTTP::Request.new("POST", "/interactions", headers, body)
  end
end
