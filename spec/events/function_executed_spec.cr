require "../spec_helper"

private def function_executed_event(replace : Hash(String, String) = {} of String => String) : Slack::Events::FunctionExecuted
  body = File.read("spec/fixtures/events/function_executed.json")
  replace.each { |original, replacement| body = body.sub(original, replacement) }
  envelope = Slack::Events.parse(body).should be_a(Slack::VerifiedEvent)
  envelope.event.should be_a(Slack::Events::FunctionExecuted)
end

describe Slack::Events::FunctionExecuted do
  it "decodes the function definition, inputs, and execution IDs" do
    event = function_executed_event

    event.type.should eq "function_executed"
    event.function_execution_id.should eq "Fx1234567O9L"
    event.workflow_execution_id.should eq "WxABC123DEF0"
    event.event_ts.should eq "1698958075.998738"
    event.inputs.should eq JSON.parse(%({"user_id":"USER12345678"}))
    event.bot_access_token.value.should eq "xwfp-synthetic-function-token"

    function = event.function
    function.id.should eq "Fn123456789O"
    function.callback_id.should eq "sample_function"
    function.title.should eq "Sample function"
    function.description.should eq "Runs sample function"
    function.type.should eq "app"
    function.app_id.should eq "AP123456789"
    function.date_created.should eq Time.unix(1694727597)
    function.date_updated.should eq Time.unix(1698947481)
    function.date_deleted.should be_nil

    input = function.input_parameters.first
    input.type.should eq "slack#/reference/objects/user-object_id"
    input.name.should eq "user_id"
    input.title.should eq "User"
    input.description.should eq "Message recipient"
    input.required?.should be_true
    function.output_parameters.map(&.title).should eq ["Greeting"]
  end

  it "reads a nonzero date_deleted as a time" do
    event = function_executed_event({ %("date_deleted": 0) => %("date_deleted": 1698950000) })
    event.function.date_deleted.should eq Time.unix(1698950000)
  end

  it "treats a parameter without is_required, title, or description as optional" do
    parameter = Slack::Events::FunctionParameter.from_json(%({"type":"string","name":"message"}))
    parameter.required?.should be_false
    parameter.title.should be_nil
    parameter.description.should be_nil
  end

  it "redacts the workflow token from inspect, to_s, and re-serialized JSON" do
    event = function_executed_event
    event.bot_access_token.to_s.should_not contain("xwfp")
    event.inspect.should_not contain("xwfp-synthetic-function-token")
    event.to_s.should_not contain("xwfp-synthetic-function-token")
    event.to_json.should_not contain("xwfp-synthetic-function-token")
  end

  it "rejects an execution without a workflow token" do
    expect_raises(JSON::SerializableError) do
      function_executed_event({ %("bot_access_token": "xwfp-synthetic-function-token") => %("bot_access_token": "") })
    end
    expect_raises(JSON::SerializableError) do
      function_executed_event({ %(,\n        "bot_access_token": "xwfp-synthetic-function-token") => "" })
    end
  end
end
