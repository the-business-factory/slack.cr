require "json"

module Slack::Models::Reactions
  # An item with reactions, from `reactions.get` and `reactions.list`.
  # `type` is `message` or `file`. A message item has `channel` and `message`;
  # a file item has `file`. Legacy file comments are not read.
  struct Item
    include JSON::Serializable
    include Slack::Api::Envelope

    getter type : String?
    getter channel : String?
    getter message : Slack::Models::Message?
    getter file : Slack::Models::File?
  end
end
