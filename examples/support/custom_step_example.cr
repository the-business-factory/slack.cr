require "../../src/slack"
require "../../src/slack/testing"
require "webmock"
require "./webmock_transport"

# Runs a custom step that waits for a user. The function listener posts an
# Approve button with the step's workflow token. The click listener completes
# the step with the approver as its output. Web API calls reach WebMock.
module OfflineCustomStepExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  STEP_TOKEN     = "xwfp-synthetic-step"
  CLICK_TOKEN    = "xwfp-synthetic-click"

  # Independently authored from the function_executed and block_actions references.
  EXECUTED = %q({"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC","event":{"type":"function_executed","function":{"id":"Fn-SYNTHETIC","callback_id":"request_approval","title":"Request approval","type":"app","input_parameters":[{"type":"slack#/types/channel_id","name":"channel_id","title":"Channel","is_required":true}],"output_parameters":[{"type":"slack#/types/user_id","name":"approver_id","title":"Approver","is_required":true}],"app_id":"A-SYNTHETIC","date_created":1789232000,"date_updated":1789232000,"date_deleted":0},"inputs":{"channel_id":"C-APPROVALS"},"function_execution_id":"Fx-APPROVAL","workflow_execution_id":"Wx-SYNTHETIC","event_ts":"1789232400.000001","bot_access_token":"xwfp-synthetic-step"},"type":"event_callback","event_id":"Ev-STEP","event_time":1789232400})
  CLICK    = %q({"type":"block_actions","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},"user":{"id":"U-APPROVER","team_id":"T-SYNTHETIC"},"trigger_id":"1789232401.synthetic.trigger","container":{"type":"message","message_ts":"1789232400.000200","channel_id":"C-APPROVALS","is_ephemeral":false},"channel":{"id":"C-APPROVALS","name":"approvals"},"bot_access_token":"xwfp-synthetic-click","function_data":{"execution_id":"Fx-APPROVAL","function":{"callback_id":"request_approval"},"inputs":{"channel_id":"C-APPROVALS"}},"interactivity":{"interactivity_pointer":"1789232401.synthetic.pointer","interactor":{"id":"U-APPROVER","secret":"synthetic-interactor-secret"}},"actions":[{"type":"button","action_id":"approval.approve","block_id":"approval.controls","text":{"type":"plain_text","text":"Approve"},"value":"approve","action_ts":"1789232401.000001"}]})

  # Each Web API call that the example made: its method, token, and JSON body.
  record Call, method : String, authorization : String?, body : JSON::Any
  record Result, executed : HTTP::Client::Response, click : HTTP::Client::Response, calls : Array(Call)

  def self.build_app : Slack::App
    transport = OfflineExample::WebMockTransport.new
    client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic-app"), transport: transport)
    app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client),
      workflow_client: ->(token : Slack::Auth::Secret) { Slack::Api::Client.new(token: token, transport: transport) })

    # The step waits for a user, so this listener does not complete it.
    app.function("request_approval") do |ctx|
      channel = ctx.inputs["channel_id"].as_s
      ctx.client.call(Slack::Api::ChatPostMessage.new(channel: channel, message: approval_request))
    end

    app.action("approval.approve") do |ctx|
      ctx.ack
      execution = ctx.function_execution || next
      execution.complete({approver_id: ctx.payload.user.try(&.id)})
    end
    app
  end

  def self.run(output : IO = STDOUT) : Result
    calls = install_web_api
    # In an application: HTTP::Server.new([receiver, *other_handlers]).listen(3000)
    receiver = Slack::App::HttpReceiver.new(build_app, Slack::Webhooks::Verifier.new(SIGNING_SECRET))

    executed = serve(receiver, signed("application/json", EXECUTED))
    output.puts "Step acknowledged: #{executed.status_code}"
    posted = calls.receive
    click = serve(receiver, signed("application/x-www-form-urlencoded", URI::Params.encode({"payload" => CLICK})))
    output.puts "Click acknowledged: #{click.status_code}"
    Result.new(executed, click, [posted, calls.receive])
  end

  def self.approval_request : UI::Message
    UI.message(fallback_text: "Approve this request?") do |builder|
      approve = UI::BlockElements::Button.new(text: UI.plain("Approve"), action_id: "approval.approve", value: "approve")
      builder.actions(elements: [approve], block_id: "approval.controls")
    end
  end

  private def self.signed(content_type : String, body : String) : HTTP::Request
    Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, content_type: content_type)
  end

  # Runs one request through the handler in memory, as `HTTP::Server` would.
  private def self.serve(handler : HTTP::Handler, request : HTTP::Request) : HTTP::Client::Response
    output = IO::Memory.new
    response = HTTP::Server::Response.new(output)
    handler.call(HTTP::Server::Context.new(request, response))
    response.close
    HTTP::Client::Response.from_io(output.rewind)
  end

  # Returns a channel that receives each Web API call in send order. Listener
  # fibers make the calls after the acknowledgment.
  private def self.install_web_api : Channel(Call)
    WebMock.allow_net_connect = false
    calls = Channel(Call).new(2)
    {"chat.postMessage"          => %({"ok":true,"channel":"C-APPROVALS","ts":"1789232400.000200"}),
     "functions.completeSuccess" => %({"ok":true})}.each do |method, reply|
      WebMock.stub(:post, "https://slack.com/api/#{method}").to_return do |request|
        body = JSON.parse(request.body || raise "Missing #{method} body")
        calls.send(Call.new(method, request.headers["Authorization"]?, body))
        HTTP::Client::Response.new(200, body: reply)
      end
    end
    calls
  end
end
