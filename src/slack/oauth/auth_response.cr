struct Slack::AuthResponse
  include JSON::Serializable

  property access_token : String,
    app_id : String,
    authed_user : Slack::Auth::User,
    bot_user_id : String?,
    enterprise : Slack::Auth::Enterprise?,
    expires_in : Int32?,
    ok : Bool,
    refresh_token : String?,
    scope : String,
    team : Slack::Auth::Team,
    token_type : String?

  def self.from_json(json : String | IO)
    pull = JSON::PullParser.new(json)
    return_value = nil
    pull.read_object do |key|
      case key
      when "ok"
        value = pull.read_bool
        case value
        when true
          return_value = new JSON::PullParser.new(json)
        else
          raise Slack::Auth::Error.new(json)
        end
      else
        pull.skip
      end
    end

    return_value || raise Slack::Auth::Error.new(json)
  end
end
