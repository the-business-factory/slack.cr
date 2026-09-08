require "./spec_helper"

describe Slack::AuthHandler do
  it "preserves installation parameters through authorization and exchange with login unset" do
    original_redirect = Slack::AuthHandler.settings.oauth_redirect_url
    original_login_redirect = Slack::SignInWithSlack.settings.sign_in_redirect_url
    original_bot_scopes = Slack.settings.bot_scopes
    original_user_scopes = Slack.settings.user_scopes
    original_secret = Slack.settings.client_secret
    begin
      redirect = "https://example.test/install?tenant=one&route=a+b%2Fc%26d&label=hello%20world"
      Slack::AuthHandler.configure(&.oauth_redirect_url=(redirect))
      Slack::SignInWithSlack.configure(&.sign_in_redirect_url=(nil))
      Slack.configure do |config|
        config.bot_scopes = ["chat:write", "incoming-webhook"]
        config.user_scopes = ["users:read", "channels:read"]
        config.client_secret = "dummy+secret&value=100%"
      end

      authorization = URI.parse(Slack::AuthHandler.new.redirect_url)
      authorization.scheme.should eq("https")
      authorization.host.should eq("slack.com")
      authorization.path.should eq("/oauth/v2/authorize")
      authorization.query_params.to_h.should eq({
        "client_id"    => Slack.settings.client_id,
        "scope"        => "chat:write,incoming-webhook",
        "user_scope"   => "users:read,channels:read",
        "redirect_uri" => redirect,
      })

      WebMock.stub(:post, "https://slack.com/api/oauth.v2.access")
        .with(headers: {"Content-Type" => "application/x-www-form-urlencoded"})
        .to_return do |request|
          form = URI::Params.parse(request.body.try(&.gets_to_end) || raise "Missing form")
          form["code"].should eq("dummy+code&value=100%")
          form["client_id"].should eq(Slack.settings.client_id)
          form["client_secret"].should eq("dummy+secret&value=100%")
          form["redirect_uri"].should eq(authorization.query_params["redirect_uri"])
          HTTP::Client::Response.new(200, body: File.read("spec/fixtures/auth_success.json"))
        end

      result = Slack::AuthHandler.run(HTTP::Request.new("GET", "/install?code=dummy%2Bcode%26value%3D100%25"))
      result.team.should_not(be_nil).id.should eq("T9TK3CUKW")
      result.team.should_not(be_nil).name.should eq("Slack Softball Team")
      result.access_token.should eq("xoxe.xoxb-1-..")
      result.authed_user.should_not(be_nil).id.should eq("U1234")
      Slack::SignInWithSlack.settings.sign_in_redirect_url.should be_nil
    ensure
      Slack::AuthHandler.configure(&.oauth_redirect_url=(original_redirect))
      Slack::SignInWithSlack.configure(&.sign_in_redirect_url=(original_login_redirect))
      Slack.configure do |config|
        config.bot_scopes = original_bot_scopes
        config.user_scopes = original_user_scopes
        config.client_secret = original_secret
      end
    end
  end

  it "raises an authentication error when Slack rejects the installation code" do
    WebMock.stub(:post, "https://slack.com/api/oauth.v2.access")
      .to_return(body: %({"ok":false,"error":"invalid_code"}))

    expect_raises(Slack::Errors::Auth) do
      Slack::AuthHandler.run(HTTP::Request.new("GET", "/install?code=dummy-rejected-code"))
    end
  end
end
