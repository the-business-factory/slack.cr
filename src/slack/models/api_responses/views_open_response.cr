abstract struct Slack::Models::ViewsOpenResponse < Slack::Model
  alias ViewsOpen = Slack::Models::ViewsOpen

  def self.from_json(json : String | IO)
    pull = JSON::PullParser.new(json)

    pull.read_object do |key|
      case key
      when "ok"
        ok = pull.read_bool
        if ok
          return ViewsOpen::Success.new JSON::PullParser.new(json)
        else
          return ViewsOpen::Error.new JSON::PullParser.new(json)
        end
      else
        pull.skip
      end
    end

    raise Slack::Errors::Api.new(json)
  end
end
