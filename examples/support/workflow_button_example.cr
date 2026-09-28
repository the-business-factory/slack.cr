require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Posts a resolved incident with workflow buttons that start link-trigger
# workflows. Slack shows workflow buttons in messages only.
module OfflineWorkflowButtonExample
  alias UI = Slack::UI::Checked

  record Incident, id : String, severity : String

  POSTMORTEM_TRIGGER = "https://slack.com/shortcuts/Ft0SYNTHETIC/postmortem"
  STATUS_TRIGGER     = "https://slack.com/shortcuts/Ft0SYNTHETIC/status"

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted = JSON.parse(request.body || raise "Missing posted message")
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000400","message":{}}))
    end

    incident = Incident.new("INC-7", "SEV2")
    postmortem = UI::BlockElements::WorkflowButton.new(
      text: UI.plain("Start postmortem"), action_id: "postmortem.start",
      style: UI::BlockElements::ButtonStyle::Primary,
      workflow: UI::CompositionObjects::Workflow.new(trigger: UI::CompositionObjects::WorkflowTrigger.new(
        url: POSTMORTEM_TRIGGER, customizable_input_parameters: {
        UI::CompositionObjects::WorkflowInputParameter.new(name: "incident_id", value: incident.id),
        UI::CompositionObjects::WorkflowInputParameter.new(name: "severity", value: incident.severity),
      })))
    status = UI::BlockElements::WorkflowButton.new(
      text: UI.plain("Post status"), action_id: "status.update",
      accessibility_label: "Post a status update for #{incident.id}",
      workflow: UI::CompositionObjects::Workflow.new(trigger: UI::CompositionObjects::WorkflowTrigger.new(url: STATUS_TRIGGER)))
    close = UI::BlockElements::Button.new(text: UI.plain("Close"), action_id: "incident.close", value: incident.id)

    message = UI.message(fallback_text: "Incident #{incident.id} needs a postmortem") do |builder|
      builder.section(UI.mrkdwn("*#{incident.id}* is resolved."), block_id: "incident", accessory: postmortem)
      builder.actions({close, status}, block_id: "incident.more")
    end
    result = Slack::Api::CheckedChatPostMessage.new(token: "xoxb-synthetic-workflow", channel: "C-SYNTHETIC",
      message: message, transport: OfflineExample::WebMockTransport.new).call
    output.puts "Posted workflow buttons for #{incident.id} to #{result.channel}/#{result.ts}"

    begin
      UI.home(&.actions({status}))
    rescue error : UI::ValidationError
      output.puts "Rejected Home tab: #{error.issues.map(&.code).join(", ")}"
    end
    body = posted
    raise "chat.postMessage was not called" unless body
    body
  end
end
