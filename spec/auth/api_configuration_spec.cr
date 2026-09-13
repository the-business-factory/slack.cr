require "../spec_helper"
require "../support/auth/fakes"
require "../support/auth/host_cases"

describe Slack::Auth::APIConfiguration do
  it "validates parsed and constructed hosts without exposing invalid values" do
    AuthSupport::INVALID_HOSTS.each do |host|
      error = expect_raises(Slack::Auth::ContractError) do
        Slack::Auth::APIConfiguration.new(URI.new(scheme: "https", host: host, path: "/api"))
      end
      error.code.should eq(Slack::Auth::ErrorCode::InvalidConfiguration)
      error.cause.should be_nil
      error.message.should eq("Authentication failure: InvalidConfiguration")
    end

    ["bad host", "bad\thost", "bad%GGhost", "bad%20host", "-host", "host..test", "256.0.0.1", "[::1]suffix", "[gg::1]"].each do |host|
      expect_raises(Slack::Auth::ContractError) do
        Slack::Auth::APIConfiguration.new(URI.parse("https://#{host}/api"))
      end.code.should eq(Slack::Auth::ErrorCode::InvalidConfiguration)
    end
  end

  it "preserves valid DNS and IP hosts, ports, and encoded paths" do
    AuthSupport::VALID_HOSTS.each do |host|
      [URI.parse("https://#{host}:8443/custom%20api"),
       URI.new(scheme: "https", host: host, port: 8443, path: "/custom%20api")].each do |uri|
        endpoint = Slack::Auth::APIConfiguration.new(uri).endpoint("team.info", "value=a%2Bb")
        endpoint.host.should eq(host)
        endpoint.port.should eq(8443)
        endpoint.request_target.should eq("/custom%20api/team.info?value=a%2Bb")
      end
    end
    Slack::Auth::APIConfiguration.new(URI.parse("https://%65xample.test/api")).base_uri.host.should eq("example.test")
  end

  it "joins custom base paths and preserves encoded query values" do
    configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.gov.example/custom/api"))
    endpoint = configuration.endpoint("conversations.info", HTTP::Params.encode({"channel" => "C /?&+"}))

    endpoint.host.should eq("api.gov.example")
    endpoint.path.should eq("/custom/api/conversations.info")
    endpoint.query_params["channel"].should eq("C /?&+")
    endpoint.to_s.should_not contain("slack.com")
  end

  it "accepts valid percent escapes in API base paths" do
    configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/custom%20api/"))

    configuration.endpoint("team.info").request_target.should eq("/custom%20api/team.info")
  end

  it "rejects unsafe endpoint and base URI forms without exposing their values" do
    invalid = [
      "http://api.example.test/api/",
      "ftp://api.example.test/api/",
      "https://user:canary-secret@api.example.test/api/",
      "https://api.example.test/api/?tenant=canary-secret",
      "https://api.example.test/api/#canary-secret",
      "https:///api/",
      "https://api.example.test:0/api/",
      "https://api.example.test/canary-secret path/",
      "https://api.example.test/canary-secret\r\nInjected: value/",
      "https://api.example.test/canary-secret%2/",
      "https://api.example.test/canary-secret%GG/",
    ]

    invalid.each do |value|
      error = expect_raises(Slack::Auth::ContractError) do
        Slack::Auth::APIConfiguration.new(URI.parse(value))
      end
      error.code.invalid_configuration?.should be_true
      error.message.to_s.should_not contain("canary-secret")
      error.message.to_s.should_not contain(value)
    end
  end

  it "allows plaintext only for explicit loopback hosts" do
    %w[localhost 127.0.0.1 127.10.20.30 ::1].each do |host|
      rendered_host = host.includes?(':') ? "[#{host}]" : host
      Slack::Auth::APIConfiguration.new(URI.parse("http://#{rendered_host}:8080/api")).base_uri.scheme.should eq("http")
    end
  end

  it "keeps configuration, transport, and credentials out of endpoint JSON" do
    transport = AuthSupport::RecordingTransport.new
    limiter = RateLimiter.new(rate: 1.0)
    endpoint = Slack::Api::ConversationsInfo.new(
      token: "canary-token",
      channel: "C1",
      configuration: Slack::Auth::APIConfiguration.new(URI.parse("https://api.gov.example/api/")),
      transport: transport,
      limiter: limiter
    )

    serialized = endpoint.to_json
    serialized.should_not contain("canary-token")
    serialized.should_not contain("api.gov.example")
    serialized.should_not contain("limiter")
    serialized.should_not contain("transport")
    JSON.parse(serialized)["channel"].as_s.should eq("C1")
  end
end
