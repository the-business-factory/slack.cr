require "../spec_helper"

describe "optional feature credentials" do
  it "validates explicit OAuth installation credentials independently of global settings" do
    store = Slack::Auth::MemoryStateStore.new
    transport = Slack::Auth::HTTPTransportFactory.new.build(Slack::Auth::TransportOptions.new)
    transport.should be_a(Slack::Auth::HTTPTransport)

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
end
