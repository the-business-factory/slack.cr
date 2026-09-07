require "spec"
require "base64"
require "../src/slack/oauth/sign_in_response"

describe Slack::SignInResponse do
  # Synthetic wire claims, not evidence of authenticated identity. No JWT shard
  # or shared spec helper is loaded: the public guard must compile on its own.
  claims = {
    "at_hash"                       => "unchecked-access-hash",
    "email"                         => "person@example.test",
    "family_name"                   => "Example",
    "given_name"                    => "Person",
    "iss"                           => "https://slack.com",
    "locale"                        => "en-US",
    "name"                          => "Person Example",
    "nonce"                         => "unchecked-nonce",
    "picture"                       => "https://example.test/avatar.png",
    "sub"                           => "U_TEST",
    "email_verified"                => true,
    "aud"                           => "test-client",
    "auth_time"                     => 1_800_000_000,
    "date_email_verified"           => 1_800_000_000,
    "exp"                           => 4_000_000_000_i64,
    "iat"                           => 1_800_000_000,
    "https://slack.com/team_domain" => "example",
    "https://slack.com/team_id"     => "T_TEST",
    "https://slack.com/team_name"   => "Example",
    "https://slack.com/user_id"     => "U_TEST",
  }
  payload = Base64.urlsafe_encode(claims.to_json, padding: false)
  unsigned_header = Base64.urlsafe_encode(%({"alg":"none"}), padding: false)
  signed_header = Base64.urlsafe_encode(%({"alg":"RS256","kid":"unknown"}), padding: false)

  {
    "unsigned JWT with complete identity claims" => "#{unsigned_header}.#{payload}.",
    "JWT with an unchecked signature"            => "#{signed_header}.#{payload}.ZmFrZQ",
    "malformed token"                            => "secret-id-token",
    "empty token"                                => "",
  }.each do |scenario, token|
    it "rejects a #{scenario} with an explicit authentication error" do
      response = Slack::SignInResponse.from_json({
        ok:           true,
        access_token: "secret-access-token",
        id_token:     token,
        token_type:   "Bearer",
      }.to_json)

      error = expect_raises(Slack::SignInResponse::VerificationUnavailable,
        "Sign in with Slack is unavailable: OIDC identity verification is not implemented") do
        response.decoded_response
      end

      error.should be_a(Slack::Errors::Auth)
      error.message.to_s.should_not contain("secret-access-token")
      error.message.to_s.should_not contain("secret-id-token")
      error.message.to_s.should_not contain(payload)
    end
  end
end
