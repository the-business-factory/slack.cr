abstract struct Slack::Models::ChatPostMessageResponse < Slack::Model
  alias ChatPostMessage = Slack::Models::ChatPostMessage

  def self.from_json(json : String | IO)
    pull = JSON::PullParser.new(json)

    pull.read_object do |key|
      case key
      when "ok"
        ok = pull.read_bool
        if ok
          return ChatPostMessage::Success.new JSON::PullParser.new(json)
        else
          return ChatPostMessage::Error.new JSON::PullParser.new(json)
        end
      else
        pull.skip
      end
    end

    raise Slack::Errors::Api.new(json)
  end
end
