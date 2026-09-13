# Run with: crystal run examples/block_kit_home.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "../src/slack"
require "webmock"
require "./support/webmock_transport"

module OfflineHomeExample
  alias UI = Slack::UI::Checked

  def self.run : Nil
    WebMock.allow_net_connect = false
    home = UI.home(callback_id: "projects", external_id: "projects-U123") do |builder|
      builder.header(text: UI.plain("Your projects"), level: 1)
      builder.context(elements: {UI.mrkdwn("*Project 42*"), UI.plain("Ready for review")})
      builder.image(image_url: "https://example.test/project.png", alt_text: "Project 42: three completed tasks and one task awaiting review", title: UI.plain("Project progress"))
      builder.actions(block_id: "controls", elements: [UI::BlockElements::Button.new(
        text: UI.plain("Refresh"), action_id: "refresh", accessibility_label: "Refresh your projects"
      )])
      builder.input(label: UI.plain("Project note"), hint: UI.plain("Press Enter to save"), block_id: "note", dispatch_action: true, optional: true,
        element: UI::BlockElements::PlainTextInput.new(action_id: "text", max_length: 3000,
          dispatch_action_config: UI::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: [UI::CompositionObjects::DispatchTrigger::OnEnterPressed])))
    end
    WebMock.stub(:post, "https://slack.com/api/views.publish").to_return do |request|
      body = JSON.parse(request.body || raise "Missing Home request")
      raise "Incorrect envelope" unless body == JSON.parse({user_id: "U123", view: home}.to_json)
      HTTP::Client::Response.new(200, body: {ok: true, view: {id: "V123", type: "home", hash: "synthetic-hash"}}.to_json)
    end
    published = Slack::Api::CheckedViewsPublish.new(token: "xoxb-synthetic-home", user_id: "U123", view: home, transport: OfflineExample::WebMockTransport.new).call
    puts "Published Home #{published.view["id"]} offline."

    # Simulated, already verified JSON. HTTP handlers use Slack.process_interaction.
    payload = {type: "block_actions", user: {id: "U123"}, container: {type: "view", view_id: "V123"},
               view: {id: "V123", type: "home", callback_id: "projects", hash: "synthetic-hash"},
               actions: [{type: "plain_text_input", block_id: "note", action_id: "text", value: "Ready to review"}],
               state: {values: {note: {text: {type: "plain_text_input", value: "Ready to review"}}}}}.to_json
    case interaction = Slack::Interaction.from_json(payload)
    when Slack::Interactions::BlockAction
      # Dispatched text actions remain UnknownAction; their state has typed access.
      raise "Expected raw text action" unless interaction.decoded_actions.first.is_a?(Slack::Interactions::UnknownAction)
      note = interaction.state_map.plain_text?("note", "text")
      raise "Incorrect note" unless note == "Ready to review"
      puts "Received Home note: #{note}"
    else
      raise "Expected Home block action"
    end
  end
end

OfflineHomeExample.run
