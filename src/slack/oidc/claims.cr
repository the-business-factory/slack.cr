require "json"

module Slack::OIDC
  # :nodoc:
  # The ID token payload. Every claim is nilable: `IDTokenVerifier` decides
  # which ones it requires. Parse it only after the signature verifies.
  struct Claims
    include JSON::Serializable

    getter iss : String?
    getter sub : String?
    getter aud : (String | Array(String))?
    getter azp : String?
    getter exp : Int64?
    getter iat : Int64?
    getter auth_time : Int64?
    getter nonce : String?
    getter at_hash : String?

    @[JSON::Field(key: "https://slack.com/team_id")]
    getter team_id : String?

    @[JSON::Field(key: "https://slack.com/user_id")]
    getter user_id : String?

    getter email : String?
    getter email_verified : Bool?
    getter name : String?
    getter given_name : String?
    getter family_name : String?
    getter locale : String?

    # Returns nil unless *payload* is a UTF-8 JSON object whose claims have
    # the expected types.
    def self.parse?(payload : Bytes) : Claims?
      text = String.new(payload)
      return unless text.valid_encoding?

      from_json(text)
    rescue JSON::ParseException | JSON::SerializableError
      nil
    end

    def inspect(io : IO) : Nil
      io << "Slack::OIDC::Claims([REDACTED])"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end
  end
end
