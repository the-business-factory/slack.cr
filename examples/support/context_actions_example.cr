require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Posts an answer with feedback buttons and a delete button for the asker,
# then reads a signed feedback click. Slack does not document the received
# action shape for these elements, so it decodes as `UnknownAction`.
module OfflineContextActionsExample
  alias UI = Slack::UI

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted = JSON.parse(request.body || raise "Missing posted message")
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000400","message":{"text":"Answer"}}))
    end

    message = UI.message(fallback_text: "Answer") do |builder|
      builder.section(UI.plain("Rotate the signing secret in the app settings."), block_id: "answer")
      builder.context_actions(answer_actions("U-ASKER"), block_id: "answer.actions")
    end
    Slack::Api::ChatPostMessage.new(token: "xoxb-synthetic-answer", channel: "C-SYNTHETIC",
      message: message, transport: OfflineExample::WebMockTransport.new).call

    output.puts "Feedback: #{read_feedback(signed_feedback_click)}"
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

  # Returns the clicked feedback value, or raises for another interaction.
  def self.read_feedback(request : HTTP::Request) : String
    interaction = Slack.process_interaction(request)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)

    action = interaction.decoded_actions.first
    unless action.is_a?(Slack::Interactions::UnknownAction) && action.type == "feedback_buttons"
      raise "Expected feedback buttons action"
    end
    action.raw["value"]?.try(&.as_s?) || raise "Missing feedback value"
  end

  # Simulated click. The action fields follow the Bolt JS FeedbackButtonsAction
  # type, because Slack's reference does not show this payload.
  def self.signed_feedback_click : HTTP::Request
    payload = %({"type":"block_actions","team":null,"actions":[{"type":"feedback_buttons","block_id":"answer.actions",) +
              %("action_id":"answer.feedback","action_ts":"1710000001.000100","value":"bad","text":{"type":"plain_text","text":"Bad"}}]})
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    HTTP::Request.new("POST", "/interactions", headers, body)
  end
end
