require "../spec_helper"
require "../support/api/webmock_client"

private def stub_functions_method(method : String, expected_body : String, response : String = %({"ok":true})) : Nil
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Authorization" => "Bearer xwfp-synthetic-function-token",
                    "Content-Type"  => "application/json; charset=utf-8"})
    .to_return do |request|
      JSON.parse(request.body || fail("Expected a JSON request body")).should eq JSON.parse(expected_body)
      HTTP::Client::Response.new(200, body: response)
    end
end

private def workflow_client : Slack::Api::Client
  ApiSupport.client(token: "xwfp-synthetic-function-token")
end

describe Slack::Api::FunctionsCompleteSuccess do
  it "sends the execution ID and outputs with the workflow token" do
    stub_functions_method("functions.completeSuccess",
      %({"function_execution_id":"Fx1234567O9L","outputs":{"user_id":"U123ABC456","count":2,"tags":["a","b"]}}))

    request = Slack::Api::FunctionsCompleteSuccess.new(
      function_execution_id: "Fx1234567O9L",
      outputs: {user_id: "U123ABC456", count: 2, tags: ["a", "b"]})
    workflow_client.call(request).ok?.should be_true
  end

  it "sends an empty outputs object for a function without outputs" do
    stub_functions_method("functions.completeSuccess", %({"function_execution_id":"Fx1234567O9L","outputs":{}}))

    request = Slack::Api::FunctionsCompleteSuccess.new(function_execution_id: "Fx1234567O9L", outputs: {} of String => String)
    workflow_client.call(request).ok?.should be_true
  end

  it "keeps its outputs when the caller changes the given hash" do
    outputs = {"user_id" => "U123ABC456"}
    request = Slack::Api::FunctionsCompleteSuccess.new(function_execution_id: "Fx1234567O9L", outputs: outputs)
    outputs["user_id"] = "U-CHANGED"
    request.outputs["user_id"] = JSON::Any.new("U-CHANGED-AGAIN")

    JSON.parse(request.body)["outputs"].should eq JSON.parse(%({"user_id":"U123ABC456"}))
  end

  it "keeps nested outputs when the caller changes the returned copy" do
    request = Slack::Api::FunctionsCompleteSuccess.new(
      function_execution_id: "Fx1234567O9L",
      outputs: {tags: ["original"], detail: {value: "original"}})
    copy = request.outputs
    copy["tags"].as_a << JSON::Any.new("changed")
    copy["detail"].as_h["value"] = JSON::Any.new("changed")

    JSON.parse(request.body).should eq JSON.parse(
      %({"function_execution_id":"Fx1234567O9L","outputs":{"tags":["original"],"detail":{"value":"original"}}}))
  end

  it "raises the Slack error when the execution is no longer running" do
    stub_functions_method("functions.completeSuccess",
      %({"function_execution_id":"Fx1234567O9L","outputs":{}}),
      %({"ok":false,"error":"execution_not_in_running_state"}))

    request = Slack::Api::FunctionsCompleteSuccess.new(function_execution_id: "Fx1234567O9L", outputs: {} of String => String)
    error = expect_raises(Slack::Api::Error) { workflow_client.call(request) }
    error.code.should eq "execution_not_in_running_state"
  end
end

describe Slack::Api::FunctionsCompleteError do
  it "sends the execution ID and error message with the workflow token" do
    stub_functions_method("functions.completeError",
      %({"function_execution_id":"Fx1234567O9L","error":"The user was not found."}))

    request = Slack::Api::FunctionsCompleteError.new(function_execution_id: "Fx1234567O9L", error: "The user was not found.")
    workflow_client.call(request).ok?.should be_true
  end

  it "raises the Slack error when the execution is no longer running" do
    stub_functions_method("functions.completeError",
      %({"function_execution_id":"Fx1234567O9L","error":"Timed out"}),
      %({"ok":false,"error":"execution_not_in_running_state"}))

    request = Slack::Api::FunctionsCompleteError.new(function_execution_id: "Fx1234567O9L", error: "Timed out")
    error = expect_raises(Slack::Api::Error) { workflow_client.call(request) }
    error.code.should eq "execution_not_in_running_state"
  end
end
