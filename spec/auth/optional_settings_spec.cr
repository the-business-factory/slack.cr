require "../spec_helper"

describe "optional feature credentials" do
  it "allows Habitat validation when API-unrelated credentials are absent" do
    original_client_id = Slack.settings.client_id
    original_client_secret = Slack.settings.client_secret
    original_signing_secret = Slack.settings.signing_secret
    begin
      Slack.configure do |settings|
        settings.client_id = nil
        settings.client_secret = nil
        settings.signing_secret = nil
      end
      Habitat.raise_if_missing_settings!
    ensure
      Slack.configure do |settings|
        settings.client_id = original_client_id
        settings.client_secret = original_client_secret
        settings.signing_secret = original_signing_secret
      end
    end
  end

  it "validates explicit OAuth installation credentials independently of global settings" do
    store = Slack::Auth::MemoryStateStore.new
    transport = Slack::Auth::HTTPTransportFactory.new.build(Slack::Auth::TransportOptions.new)

    [{"", "synthetic-secret"}, {"synthetic-client", " \t"}].each do |client_id, client_secret|
      configuration = Slack::Auth::OAuthConfiguration.new(
        URI.parse("https://slack.com/oauth/v2/authorize"),
        URI.parse("https://slack.com/api/oauth.v2.access"),
        client_id,
        Slack::Auth::Secret.new(client_secret),
        URI.parse("https://example.test/install")
      )

      error = expect_raises(Slack::Auth::ContractError) do
        Slack::AuthHandler.new(configuration, store, transport)
      end
      error.code.should eq(Slack::Auth::ErrorCode::InvalidConfiguration)
    end
  end

  [nil, ""].each do |missing|
    it "rejects #{missing.nil? ? "missing" : "blank"} legacy sign-in and signing credentials at use" do
      original_client_id = Slack.settings.client_id
      original_client_secret = Slack.settings.client_secret
      original_signing_secret = Slack.settings.signing_secret
      original_login_redirect = Slack::SignInWithSlack.settings.sign_in_redirect_url
      begin
        Slack::SignInWithSlack.configure(&.sign_in_redirect_url = "https://example.test/login")

        Slack.configure(&.client_id = missing)
        expect_raises(Slack::Auth::ContractError) { Slack::SignInWithSlack.new.redirect_url }

        Slack.configure do |settings|
          settings.client_id = "synthetic-client"
          settings.client_secret = missing
        end
        expect_raises(Slack::Auth::ContractError) do
          Slack::SignInWithSlack.run(HTTP::Request.new("GET", "/login?code=synthetic"))
        end

        Slack.configure(&.signing_secret = missing)
        expect_raises(Slack::Auth::ContractError) do
          Slack::Webhooks::Signature.new("1", "body").compute
        end
      ensure
        Slack.configure do |settings|
          settings.client_id = original_client_id
          settings.client_secret = original_client_secret
          settings.signing_secret = original_signing_secret
        end
        Slack::SignInWithSlack.configure(&.sign_in_redirect_url = original_login_redirect)
      end
    end
  end
end
