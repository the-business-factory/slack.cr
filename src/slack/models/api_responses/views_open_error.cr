require "./views_open_response"

struct Slack::Models::ViewsOpenError < Slack::Models::ViewsOpenResponse
  properties_with_initializer \
    error : String,
    ok : Bool,
    response_metadata : JSON::Any?
end
