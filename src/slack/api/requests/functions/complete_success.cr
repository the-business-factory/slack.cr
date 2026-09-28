require "json"

module Slack::Api
  # Completes a custom function execution with its outputs.
  # See https://docs.slack.dev/reference/methods/functions.completeSuccess.
  #
  # Send it with a client whose token is the `bot_access_token` of the
  # `function_executed` event. *outputs* is keyed by output parameter name.
  #
  # ```
  # client = Slack::Api::Client.new(token: event.bot_access_token)
  # client.call(Slack::Api::FunctionsCompleteSuccess.new(
  #   function_execution_id: event.function_execution_id,
  #   outputs: {user_id: "U123ABC456"}))
  # ```
  struct FunctionsCompleteSuccess < Request(Models::DefaultResponse)
    include JsonBody
    include JSON::Serializable

    getter function_execution_id : String
    @outputs : Hash(String, JSON::Any)

    # Copies *outputs* as JSON values, so later changes to the argument have no effect.
    def initialize(@function_execution_id : String, outputs : NamedTuple | Hash)
      @outputs = JSON.parse(outputs.to_json).as_h
    end

    # A deep copy of the outputs.
    def outputs : Hash(String, JSON::Any)
      @outputs.clone
    end

    def method_path : String
      "functions.completeSuccess"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
