require "../../../src/slack/testing"
require "../auth/oauth_state_fakes"

# Pre-signed Sign in with Slack fixtures. spec/fixtures/oidc/generate.sh makes
# them with the OpenSSL CLI; provenance.yml lists what each one changes.
module OIDCFixtures
  extend self

  CLIENT_ID    = "1234.5678"
  ACCESS_TOKEN = "xoxp-synthetic-sign-in"
  NONCE        = "synthetic-nonce"
  ISSUED_AT    = Time.unix(1_760_000_000)
  EXPIRES_AT   = Time.unix(1_760_000_300)
  JWKS_URI     = "https://slack.com/openid/connect/keys"

  def read(name : String) : String
    File.read("spec/fixtures/oidc/#{name}")
  end

  def token(name : String = "valid") : String
    read("id_token_#{name}.txt")
  end

  def jwks : String
    read("jwks.json")
  end

  def clock(now : Time = ISSUED_AT + 60.seconds) : OAuthStateSupport::Clock
    OAuthStateSupport::Clock.new(now)
  end

  def configuration : Slack::OIDC::Configuration
    Slack::OIDC::Configuration.new(CLIENT_ID, Slack::Auth::Secret.new("synthetic-secret"),
      URI.parse("https://app.example.test/slack/sign-in/callback"))
  end

  def expect_contract_error(code : Slack::Auth::ErrorCode, &) : Slack::Auth::ContractError
    error = expect_raises(Slack::Auth::ContractError) { yield }
    error.code.should eq code
    error
  end
end
