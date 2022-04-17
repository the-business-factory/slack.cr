struct Slack::Models::ViewsOpen < Slack::Model
  properties_with_initializer ok : Bool, view : JSON::Any
end
