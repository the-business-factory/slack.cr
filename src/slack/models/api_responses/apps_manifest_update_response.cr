abstract struct Slack::Models::AppsManifestUpdateResponse < Slack::Model
  alias AppsManifestUpdate = Slack::Models::AppsManifestUpdate

  def self.from_json(json : String | IO)
    pull = JSON::PullParser.new(json)

    pull.read_object do |key|
      case key
      when "ok"
        ok = pull.read_bool
        if ok
          return AppsManifestUpdate::Success.new JSON::PullParser.new(json)
        else
          return AppsManifestUpdate::Error.new JSON::PullParser.new(json)
        end
      else
        pull.skip
      end
    end

    raise Slack::Errors::Api.new(json)
  end
end
