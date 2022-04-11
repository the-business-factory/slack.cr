module Slack::Models::ChatPostMessage
  struct Success < Slack::Models::ChatPostMessageResponse
    properties_with_initializer \
      ok : Bool,
      channel : String?,
      message : JSON::Any,
      ts : String
  end
end
