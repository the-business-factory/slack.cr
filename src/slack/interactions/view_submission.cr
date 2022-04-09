struct Slack::Interactions::ViewSubmission < Slack::Interaction
  property \
    response_urls : JSON::Any,
    team : JSON::Any,
    user : JSON::Any,
    view : JSON::Any
end
