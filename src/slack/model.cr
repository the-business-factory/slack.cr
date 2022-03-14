abstract struct Slack::Model
  include JSON::Serializable
  include Slack::InitializerMacros

  def self.keyed_json_object(json : String | IO, find_key : String, &block)
    pull = JSON::PullParser.new(json)
    return_value = nil
    pull.read_object do |key|
      if key == find_key
        return_value = yield pull
      else
        pull.skip
      end
    end
    return_value || raise Slack::Errors::Api.new(json)
  end

  def self.keyed_json_object(json : String | IO, find_key : String)
    keyed_json_object(json, find_key) do |pull|
      new(pull)
    end
  end
end
