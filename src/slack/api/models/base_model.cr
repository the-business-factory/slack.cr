abstract struct Slack::Api::BaseModel
  include JSON::Serializable

  def self.keyed_json_object(json : String | IO, find_key : String)
    pull = JSON::PullParser.new(json)
    return_value = nil
    pull.read_object do |key|
      if key == find_key
        return_value = new(pull)
      else
        pull.skip
      end
    end
    return_value || raise Slack::Api::Error.new(json)
  end
end
