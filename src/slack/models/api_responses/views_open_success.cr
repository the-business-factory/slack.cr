require "./views_open_response"

struct Slack::Models::ViewsOpenSuccess < Slack::Models::ViewsOpenResponse
  properties_with_initializer ok : Bool, view : JSON::Any
end
