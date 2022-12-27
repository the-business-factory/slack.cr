struct Slack::SignInResponse
  include JSON::Serializable

  struct DecodedResponse
    include JSON::Serializable

    property \
      at_hash : String,
      email : String,
      family_name : String,
      given_name : String,
      iss : String,
      locale : String,
      name : String,
      nonce : String,
      picture : String,
      sub : String

    property? email_verified = false

    # TODO: Turn these all into proper Time objects
    property aud : String
    property auth_time : Int64
    property date_email_verified : Int64
    property exp : Int64
    property iat : Int64

    @[JSON::Field(key: "https://slack.com/team_domain")]
    property team_domain : String

    @[JSON::Field(key: "https://slack.com/team_id")]
    property team_id : String

    @[JSON::Field(key: "https://slack.com/team_name")]
    property team_name : String

    @[JSON::Field(key: "https://slack.com/user_id")]
    property user_id : String
  end

  property \
    access_token : String,
    id_token : String,
    token_type : String

  property? ok = true

  def decoded_response
    DecodedResponse.from_json(
      JWT.decode(id_token, verify: false, validate: false)[0].to_json
    )
  end

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
          raise Errors::Auth.new(json)
        end
      else
        pull.skip
      end
    end

    return_value || raise Errors::Auth.new(json)
  end
end
