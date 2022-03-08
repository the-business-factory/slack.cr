struct Slack::Models::DirectMessage < Slack::Models::Base
  property user : String

  def self.from_json(json : String | IO)
    keyed_json_object(json, find_key: "channel")
  end
end
