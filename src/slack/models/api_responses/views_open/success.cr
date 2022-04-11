struct Slack::Models::ViewsOpen::Success < Slack::Models::ViewsOpenResponse
  properties_with_initializer ok : Bool, view : JSON::Any
end
