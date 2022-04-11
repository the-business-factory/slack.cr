module Slack::Models::ChatPostMessage
  struct Error < Slack::Models::ChatPostMessageResponse
    properties_with_initializer \
      error : String,
      errors : JSON::Any?,
      ok : Bool
  end
end
