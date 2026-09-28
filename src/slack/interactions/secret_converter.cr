# :nodoc:
# Decodes a received token into `Auth::Secret` so `inspect` and `to_s` redact it.
# An empty token is a malformed payload, not a missing one.
module Slack::Interactions::SecretConverter
  def self.from_json(pull : JSON::PullParser) : Slack::Auth::Secret
    value = pull.read_string
    pull.raise("Expected a non-empty token") if value.empty?
    Slack::Auth::Secret.new(value)
  end
end
