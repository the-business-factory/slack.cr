require "json"

module Slack::Models
  # The `api.test` result: the arguments that Slack received.
  struct ApiTest
    include JSON::Serializable

    getter args : Hash(String, String) = {} of String => String
  end
end
