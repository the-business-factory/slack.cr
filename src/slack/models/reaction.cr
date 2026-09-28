require "json"

module Slack::Models
  # One emoji reaction on a message or file: the emoji name, the reaction
  # count, and the users who reacted. Slack can shorten `users`; request
  # `full: true` from `reactions.get` or `reactions.list` for the whole list.
  struct Reaction
    include JSON::Serializable

    getter name : String
    getter count : Int32
    getter users : Array(String)
  end
end
