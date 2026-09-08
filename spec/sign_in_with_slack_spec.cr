require "./spec_helper"

describe Slack::SignInWithSlack do
  it "preserves login parameters and refuses an unverified identity after token exchange" do
    original_redirect = Slack::SignInWithSlack.settings.sign_in_redirect_url
    original_scopes = Slack::SignInWithSlack.settings.scopes
    begin
      redirect = "https://example.test/login?tenant=one&route=a+b%2Fc%26d&label=hello%20world"
      Slack::SignInWithSlack.configure do |config|
        config.sign_in_redirect_url = redirect
        config.scopes = ["openid", "email", "profile"]
      end

      authorization = URI.parse(Slack::SignInWithSlack.new.redirect_url)
      authorization.scheme.should eq("https")
      authorization.host.should eq("slack.com")
      authorization.path.should eq("/openid/connect/authorize")
      authorization.query_params.to_h.should eq({
        "client_id"     => Slack.settings.client_id,
        "scope"         => "openid email profile",
        "response_type" => "code",
        "redirect_uri"  => redirect,
      })

      exchange = WebMock.stub(:post, "https://slack.com/api/openid.connect.token")
        .with(headers: {"Content-Type" => "application/x-www-form-urlencoded"})
        .to_return do |request|
          request.headers["Accept"].split(';').first.should eq("application/json")
          form = URI::Params.parse(request.body.try(&.gets_to_end) || raise "Missing form")
          form.to_h.should eq({
            "code"          => "dummy+code&value=100%",
            "client_id"     => Slack.settings.client_id,
            "client_secret" => Slack.settings.client_secret,
            "grant_type"    => "authorization_code",
            "redirect_uri"  => authorization.query_params["redirect_uri"],
          })
          HTTP::Client::Response.new(200, body: {
            ok:           true,
            access_token: "dummy-access-token",
            id_token:     "dummy-unverified-id-token",
            token_type:   "Bearer",
          }.to_json)
        end

      error = expect_raises(Slack::SignInResponse::VerificationUnavailable) do
        Slack::SignInWithSlack.run(HTTP::Request.new("GET", "/login?code=dummy%2Bcode%26value%3D100%25"))
      end
      exchange.calls.should eq(1)
      error.message.to_s.should_not contain("dummy-access-token")
      error.message.to_s.should_not contain("dummy-unverified-id-token")
    ensure
      Slack::SignInWithSlack.configure do |config|
        config.sign_in_redirect_url = original_redirect
        config.scopes = original_scopes
      end
    end
  end
end
