struct Slack::Models::ViewsOpen::Error < Slack::Models::ViewsOpenResponse
  properties_with_initializer \
    error : String,
    ok : Bool,
    response_metadata : JSON::Any?
end
