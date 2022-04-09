abstract struct Slack::Models::ViewsOpenResponse < Slack::Model
  def self.from_json(json : String | IO)
    pull = JSON::PullParser.new(json)

    pull.read_object do |key|
      case key
      when "ok"
        ok = pull.read_bool
        if ok
          return Slack::Models::ViewsOpenSuccess.new JSON::PullParser.new(json)
        else
          return Slack::Models::ViewsOpenError.new JSON::PullParser.new(json)
        end
      else
        pull.skip
      end
    end

    raise Slack::Errors::Api.new(json)
  end
end
