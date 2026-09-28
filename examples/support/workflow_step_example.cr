require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Runs a custom workflow step: completes one execution and fails another.
module OfflineWorkflowStepExample
  TOKEN = "xwfp-synthetic-workflow-step"

  # Independently authored `function_executed` deliveries; the second one has no user input.
  COMPLETE_BODY = %q({"type":"event_callback","token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC","event_id":"Ev-STEP-1","event_time":1789232400,"authorizations":[],"event":{"type":"function_executed","function":{"id":"Fn-SYNTHETIC","callback_id":"assign_reviewer","title":"Assign reviewer","type":"app","input_parameters":[{"type":"slack#/types/user_id","name":"user_id","title":"Reviewer","is_required":true}],"output_parameters":[{"type":"slack#/types/user_id","name":"reviewer_id","title":"Reviewer","is_required":true}],"app_id":"A-SYNTHETIC","date_created":1789232000,"date_updated":1789232000,"date_deleted":0},"inputs":{"user_id":"U-REVIEWER"},"function_execution_id":"Fx-STEP-1","workflow_execution_id":"Wx-SYNTHETIC","event_ts":"1789232400.000001","bot_access_token":"xwfp-synthetic-workflow-step"}})
  FAIL_BODY     = COMPLETE_BODY.sub(%("Ev-STEP-1"), %("Ev-STEP-2"))
    .sub(%({"user_id":"U-REVIEWER"}), "{}")
    .sub(%("Fx-STEP-1"), %("Fx-STEP-2"))

  # Returns the parsed JSON bodies that the step sent to Slack, in order.
  def self.run(output : IO = STDOUT) : Array(JSON::Any)
    WebMock.allow_net_connect = false
    sent = [] of JSON::Any
    {"functions.completeSuccess", "functions.completeError"}.each do |method|
      WebMock.stub(:post, "https://slack.com/api/#{method}")
        .with(headers: {"Authorization" => "Bearer #{TOKEN}"})
        .to_return do |request|
          sent << JSON.parse(request.body.to_s)
          HTTP::Client::Response.new(200, body: %({"ok":true}))
        end
    end

    {COMPLETE_BODY, FAIL_BODY}.each do |body|
      envelope = Slack.from_json(body)
      raise "Expected an event callback" unless envelope.is_a?(Slack::VerifiedEvent)
      event = envelope.event
      handle(event, output) if event.is_a?(Slack::Events::FunctionExecuted)
    end
    sent
  end

  # Each execution has its own workflow token; use it as the client token.
  def self.handle(event : Slack::Events::FunctionExecuted, output : IO) : Nil
    client = Slack::Api::Client.new(token: event.bot_access_token, transport: OfflineExample::WebMockTransport.new)
    execution_id = event.function_execution_id

    if reviewer = event.inputs["user_id"]?.try(&.as_s?)
      client.call(Slack::Api::FunctionsCompleteSuccess.new(function_execution_id: execution_id, outputs: {reviewer_id: reviewer}))
      output.puts "Completed #{event.function.callback_id} #{execution_id}: #{reviewer}"
    else
      client.call(Slack::Api::FunctionsCompleteError.new(function_execution_id: execution_id, error: "Choose a reviewer."))
      output.puts "Failed #{event.function.callback_id} #{execution_id}: no reviewer"
    end
  end
end
