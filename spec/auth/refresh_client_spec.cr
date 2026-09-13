require "../spec_helper"
require "../support/rotation/helpers"

describe Slack::Auth::RefreshClient do
  it "sends one form refresh grant with Basic credentials to the configured endpoint" do
    transport = RotationSupport::Transport.new
    configuration = RotationSupport.configuration
    client = Slack::Auth::RefreshClient.new(configuration, transport)
    configuration.token_uri.host = "changed.test"
    client.refresh(Slack::Auth::Secret.new("synthetic-refresh+&="))
    transport.requests.size.should eq(1)
    request = transport.requests.first
    request.method.should eq("POST")
    request.uri.to_s.should eq("https://example.test/custom/token")
    request.headers["Content-Type"].should eq("application/x-www-form-urlencoded")
    request.headers["Authorization"].should eq("Basic " + Base64.strict_encode("synthetic-client:synthetic-secret"))
    params = URI::Params.parse(request.body.should_not(be_nil))
    params.to_h.should eq({"grant_type" => "refresh_token", "refresh_token" => "synthetic-refresh+&="})
    client.inspect.should_not contain("synthetic")
  end

  it "rejects unsafe endpoints before transport use" do
    {"http://example.test/token", "https://example.test/token?client_secret=x", "https://user:secret@example.test/token", "https://bad_host/token"}.each do |endpoint|
      config = RotationSupport.configuration
      config = Slack::Auth::OAuthConfiguration.new(config.authorization_uri, URI.parse(endpoint), config.client_id,
        config.client_secret, config.redirect_uri)
      transport = RotationSupport::Transport.new
      expect_raises(Slack::Auth::ContractError) { Slack::Auth::RefreshClient.new(config, transport) }.code.should eq(Slack::Auth::ErrorCode::InvalidConfiguration)
      transport.requests.should be_empty
    end
  end

  it "redacts unexpected transport exceptions as unknown outcomes" do
    transport = RotationSupport::Transport.new
    transport.before_response = -> : Nil { raise "synthetic-secret" }
    client = Slack::Auth::RefreshClient.new(RotationSupport.configuration, transport)
    error = expect_raises(Slack::Auth::ContractError) { client.refresh(Slack::Auth::Secret.new("synthetic-refresh")) }
    error.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
    error.inspect.should_not contain("synthetic")
    error.cause.should be_nil
  end
end
