require "json"

module Slack::Api
  # Fails a custom function execution with a message that explains why it failed.
  # See https://docs.slack.dev/reference/methods/functions.completeError.
  #
  # Send it with a client whose token is the `bot_access_token` of the
  # `function_executed` event.
  struct FunctionsCompleteError < Request(Models::DefaultResponse)
    include JsonBody
    include JSON::Serializable

    getter function_execution_id : String
    getter error : String

    def initialize(@function_execution_id : String, @error : String)
    end

    def method_path : String
      "functions.completeError"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
