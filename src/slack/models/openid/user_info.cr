require "json"

module Slack::Models::OpenID
  # The `openid.connect.userInfo` result: the signed-in user's profile. Slack
  # sends `email` fields only with the `email` scope, and the names, locale,
  # and images only with the `profile` scope.
  struct UserInfo
    include JSON::Serializable
    include Slack::Api::Envelope

    getter sub : String

    @[JSON::Field(key: "https://slack.com/user_id")]
    getter user_id : String

    @[JSON::Field(key: "https://slack.com/team_id")]
    getter team_id : String

    getter email : String?
    getter? email_verified : Bool?
    # Unix time of the email verification.
    getter date_email_verified : Int64?
    getter name : String?
    getter picture : String?
    getter given_name : String?
    getter family_name : String?
    getter locale : String?

    @[JSON::Field(key: "https://slack.com/team_name")]
    getter team_name : String?

    @[JSON::Field(key: "https://slack.com/team_domain")]
    getter team_domain : String?

    @[JSON::Field(key: "https://slack.com/user_image_24")]
    getter user_image_24 : String?

    @[JSON::Field(key: "https://slack.com/user_image_32")]
    getter user_image_32 : String?

    @[JSON::Field(key: "https://slack.com/user_image_48")]
    getter user_image_48 : String?

    @[JSON::Field(key: "https://slack.com/user_image_72")]
    getter user_image_72 : String?

    @[JSON::Field(key: "https://slack.com/user_image_192")]
    getter user_image_192 : String?

    @[JSON::Field(key: "https://slack.com/user_image_512")]
    getter user_image_512 : String?

    @[JSON::Field(key: "https://slack.com/team_image_34")]
    getter team_image_34 : String?

    @[JSON::Field(key: "https://slack.com/team_image_44")]
    getter team_image_44 : String?

    @[JSON::Field(key: "https://slack.com/team_image_68")]
    getter team_image_68 : String?

    @[JSON::Field(key: "https://slack.com/team_image_88")]
    getter team_image_88 : String?

    @[JSON::Field(key: "https://slack.com/team_image_102")]
    getter team_image_102 : String?

    @[JSON::Field(key: "https://slack.com/team_image_132")]
    getter team_image_132 : String?

    @[JSON::Field(key: "https://slack.com/team_image_230")]
    getter team_image_230 : String?

    # Slack's `https://slack.com/team_image_default` flag.
    @[JSON::Field(key: "https://slack.com/team_image_default")]
    getter? team_image_default : Bool?
  end
end
