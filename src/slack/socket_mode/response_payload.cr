require "json"

# A response body that an `Acknowledgment` can carry. Slack's response types,
# such as `Slack::Commands::Response` and `Slack::Interactions::ModalErrors`,
# include this module, so the Socket Mode transport does not depend on them.
# The acknowledgment writes the body with `#to_json` as its `payload` field.
module Slack::SocketMode::ResponsePayload
  abstract def to_json(json : JSON::Builder) : Nil
end
