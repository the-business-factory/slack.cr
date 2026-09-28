require "../spec_helper"
require "../support/app/signed_request"

# Payloads below are authored independently from the Slack references:
# https://docs.slack.dev/reference/events/function_executed
# https://docs.slack.dev/reference/interaction-payloads/block_actions-payload
# https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload
# https://docs.slack.dev/reference/methods/functions.completeSuccess
# https://docs.slack.dev/reference/methods/functions.completeError
private FUNCTION_EXECUTED = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"function_executed",
            "function":{"id":"Fn-SYNTHETIC","callback_id":"approve_request","title":"Approve request",
                        "type":"app","app_id":"A-SYNTHETIC","date_created":1789232000,"date_updated":1789232000,
                        "date_deleted":0,
                        "input_parameters":[{"type":"slack#/types/user_id","name":"requester","is_required":true}],
                        "output_parameters":[{"type":"slack#/types/user_id","name":"approver","is_required":true}]},
            "inputs":{"requester":"U-REQUESTER"},
            "function_execution_id":"Fx-SYNTHETIC","workflow_execution_id":"Wx-SYNTHETIC",
            "event_ts":"1789232400.000100","bot_access_token":"xwfp-synthetic-workflow-token"},
   "type":"event_callback","event_id":"Ev-FUNCTION","event_time":1789232400}
  JSON

private FUNCTION_BLOCK_ACTIONS = <<-JSON
  {"type":"block_actions","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},
   "user":{"id":"U-APPROVER","team_id":"T-SYNTHETIC"},"trigger_id":"1789232400.synthetic.trigger",
   "container":{"type":"message","message_ts":"1789232400.000200","channel_id":"C-SYNTHETIC","is_ephemeral":false},
   "channel":{"id":"C-SYNTHETIC","name":"approvals"},
   "bot_access_token":"xwfp-synthetic-interaction-token",
   "function_data":{"execution_id":"Fx-SYNTHETIC","function":{"callback_id":"approve_request"},
                    "inputs":{"requester":"U-REQUESTER"}},
   "interactivity":{"interactivity_pointer":"1789232400.synthetic.pointer",
                    "interactor":{"id":"U-APPROVER","secret":"synthetic-interactor-secret"}},
   "actions":[{"type":"button","action_id":"approve","block_id":"decision",
               "text":{"type":"plain_text","text":"Approve"},"value":"yes","action_ts":"1789232401.000001"}]}
  JSON

private PLAIN_BLOCK_ACTIONS = <<-JSON
  {"type":"block_actions","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},
   "user":{"id":"U-APPROVER","team_id":"T-SYNTHETIC"},"trigger_id":"1789232400.synthetic.trigger",
   "actions":[{"type":"button","action_id":"approve","block_id":"decision",
               "text":{"type":"plain_text","text":"Approve"},"value":"yes","action_ts":"1789232401.000001"}]}
  JSON

private FUNCTION_VIEW_SUBMISSION = <<-JSON
  {"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},
   "user":{"id":"U-APPROVER","team_id":"T-SYNTHETIC"},"trigger_id":"1789232400.synthetic.trigger",
   "bot_access_token":"xwfp-synthetic-view-token",
   "function_data":{"execution_id":"Fx-VIEW","function":{"callback_id":"approve_request"},"inputs":{}},
   "view":{"id":"V-SYNTHETIC","type":"modal","callback_id":"approval.reason","team_id":"T-SYNTHETIC",
           "state":{"values":{"reason":{"reason.text":{"type":"plain_text_input","value":"Budget is closed"}}}}},
   "response_urls":[]}
  JSON

# One transport for the app client and every workflow client, so a spec can
# check which token each request carries.
private class FunctionHarness
  getter transport = Slack::Testing::RecordingTransport.new
  getter app : Slack::App

  def initialize
    transport = @transport
    app_client = Slack::Api::Client.new(token: "xoxb-synthetic-app-token", transport: transport)
    @app = Slack::App.new(
      authorizer: Slack::App::SingleTokenAuthorizer.new(app_client),
      workflow_client: ->(token : Slack::Auth::Secret) { Slack::Api::Client.new(token: token, transport: transport) })
  end

  def receive(request : HTTP::Request) : AppSupport::Reply
    AppSupport.run(Slack::App::HttpReceiver.new(@app, AppSupport::VERIFIER), request)
  end

  def request : Slack::Auth::TransportRequest
    requests = @transport.requests
    requests.size.should eq 1
    requests.first
  end
end

private def expect_request(request : Slack::Auth::TransportRequest, method : String, token : String, body : String) : Nil
  request.uri.to_s.should eq "https://slack.com/api/#{method}"
  request.headers["Authorization"].should eq "Bearer #{token}"
  JSON.parse(request.body.should_not(be_nil)).should eq JSON.parse(body)
end

describe "Slack::App custom steps" do
  it "routes function_executed by callback ID and completes it with the workflow token" do
    harness = FunctionHarness.new
    harness.transport.respond(%({"ok":true}))
    done = Channel(String).new(1)
    harness.app.function("other_step") { |_ctx| done.send("wrong listener") }
    harness.app.function("approve_request") do |ctx|
      ctx.complete({approver: ctx.inputs["requester"].as_s})
      done.send(ctx.event.function_execution_id)
    end

    reply = harness.receive(AppSupport.json(FUNCTION_EXECUTED))

    reply.status.should eq 200
    reply.body.should be_empty
    receive_soon(done).should eq "Fx-SYNTHETIC"
    expect_request(harness.request, "functions.completeSuccess", "xwfp-synthetic-workflow-token",
      %({"function_execution_id":"Fx-SYNTHETIC","outputs":{"approver":"U-REQUESTER"}}))
  end

  it "fails a function execution with an error message" do
    harness = FunctionHarness.new
    harness.transport.respond(%({"ok":true}))
    done = Channel(Nil).new(1)
    harness.app.function("approve_request") do |ctx|
      ctx.fail("Approver not found")
      done.send(nil)
    end

    harness.receive(AppSupport.json(FUNCTION_EXECUTED)).status.should eq 200
    receive_soon(done)

    expect_request(harness.request, "functions.completeError", "xwfp-synthetic-workflow-token",
      %({"function_execution_id":"Fx-SYNTHETIC","error":"Approver not found"}))
  end

  it "gives the function listener a client with the workflow token" do
    harness = FunctionHarness.new
    harness.transport.respond(%({"ok":true,"url":"https://synthetic.slack.com/","team_id":"T-SYNTHETIC"}))
    done = Channel(Nil).new(1)
    harness.app.function("approve_request") do |ctx|
      ctx.client.call("auth.test")
      done.send(nil)
    end

    harness.receive(AppSupport.json(FUNCTION_EXECUTED))
    receive_soon(done)

    harness.request.headers["Authorization"].should eq "Bearer xwfp-synthetic-workflow-token"
  end

  it "completes the function from a block action that the function created" do
    harness = FunctionHarness.new
    harness.transport.respond(%({"ok":true}))
    inputs = Channel(JSON::Any?).new(1)
    harness.app.action("approve") do |ctx|
      ctx.ack
      execution = ctx.function_execution
      execution.try(&.complete({approver: ctx.payload.user.try(&.id)}))
      inputs.send(execution.try(&.inputs))
    end

    reply = harness.receive(AppSupport.interaction(FUNCTION_BLOCK_ACTIONS))

    reply.status.should eq 200
    receive_soon(inputs).should eq JSON.parse(%({"requester":"U-REQUESTER"}))
    expect_request(harness.request, "functions.completeSuccess", "xwfp-synthetic-interaction-token",
      %({"function_execution_id":"Fx-SYNTHETIC","outputs":{"approver":"U-APPROVER"}}))
  end

  it "fails the function from a view submission that the function created" do
    harness = FunctionHarness.new
    harness.transport.respond(%({"ok":true}))
    done = Channel(Bool).new(1)
    harness.app.view("approval.reason") do |ctx|
      ctx.ack
      execution = ctx.function_execution
      execution.try(&.fail(ctx.payload.plain_text?("reason", "reason.text") || "Denied"))
      done.send(!execution.nil?)
    end

    harness.receive(AppSupport.interaction(FUNCTION_VIEW_SUBMISSION)).status.should eq 200
    receive_soon(done).should be_true

    expect_request(harness.request, "functions.completeError", "xwfp-synthetic-view-token",
      %({"function_execution_id":"Fx-VIEW","error":"Budget is closed"}))
  end

  it "has no function execution for an interaction without function data" do
    harness = FunctionHarness.new
    executions = Channel(Slack::App::FunctionExecution?).new(1)
    harness.app.action("approve") { |ctx| executions.send(ctx.function_execution) }

    harness.receive(AppSupport.interaction(PLAIN_BLOCK_ACTIONS)).status.should eq 200

    receive_soon(executions).should be_nil
    harness.transport.requests.should be_empty
  end
end

# Receives what the listener fiber sends after it acknowledges. A listener
# that raises sends nothing, so the spec fails instead of waiting forever.
private def receive_soon(channel : Channel(T)) : T forall T
  select
  when value = channel.receive
    value
  when timeout(1.second)
    fail "the listener did not finish"
  end
end
