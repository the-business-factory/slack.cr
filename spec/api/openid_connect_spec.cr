require "../spec_helper"
require "../../src/slack/testing"

module OpenIDConnectSpecSupport
  extend self

  # From https://docs.slack.dev/reference/methods/openid.connect.token, with synthetic values.
  TOKEN_RESPONSE = %({"ok":true,"access_token":"xoxp-synthetic-sign-in","token_type":"Bearer","id_token":"synthetic.id.token"})

  # From https://docs.slack.dev/reference/methods/openid.connect.userInfo, with synthetic values.
  USER_INFO_RESPONSE = <<-JSON
    {
      "ok": true,
      "sub": "U-SYNTHETIC",
      "https://slack.com/user_id": "U-SYNTHETIC",
      "https://slack.com/team_id": "T-SYNTHETIC",
      "email": "alice@example.test",
      "email_verified": true,
      "date_email_verified": 1622128723,
      "name": "alice",
      "picture": "https://images.example.test/alice.png",
      "given_name": "Alice",
      "family_name": "Example",
      "locale": "en-US",
      "https://slack.com/team_name": "Example Team",
      "https://slack.com/team_domain": "example-team",
      "https://slack.com/user_image_24": "https://images.example.test/24.png",
      "https://slack.com/user_image_32": "https://images.example.test/32.png",
      "https://slack.com/user_image_48": "https://images.example.test/48.png",
      "https://slack.com/user_image_72": "https://images.example.test/72.png",
      "https://slack.com/user_image_192": "https://images.example.test/192.png",
      "https://slack.com/user_image_512": "https://images.example.test/512.png",
      "https://slack.com/team_image_34": "https://images.example.test/t34.png",
      "https://slack.com/team_image_44": "https://images.example.test/t44.png",
      "https://slack.com/team_image_68": "https://images.example.test/t68.png",
      "https://slack.com/team_image_88": "https://images.example.test/t88.png",
      "https://slack.com/team_image_102": "https://images.example.test/t102.png",
      "https://slack.com/team_image_132": "https://images.example.test/t132.png",
      "https://slack.com/team_image_230": "https://images.example.test/t230.png",
      "https://slack.com/team_image_default": true
    }
    JSON

  def exchange : Slack::Api::OpenIDConnectToken
    Slack::Api::OpenIDConnectToken.new(client_id: "1234.5678", client_secret: "synthetic-secret",
      code: "synthetic-code", redirect_uri: "https://app.example.test/slack/sign-in")
  end

  # The exchange needs no token, so the client sends no Authorization header.
  def token_less_client(transport : Slack::Auth::Transport) : Slack::Api::Client
    Slack::Api::Client.new(token: nil, transport: transport)
  end
end

describe Slack::Api::OpenIDConnectToken do
  it "posts the authorization code grant without a token" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(OpenIDConnectSpecSupport::TOKEN_RESPONSE)

    OpenIDConnectSpecSupport.token_less_client(transport).call(OpenIDConnectSpecSupport.exchange)

    request = transport.requests.first
    request.method.should eq "POST"
    request.uri.to_s.should eq "https://slack.com/api/openid.connect.token"
    request.headers["Content-Type"].should eq "application/x-www-form-urlencoded"
    request.headers["Authorization"]?.should be_nil
    request.body.should eq "grant_type=authorization_code&client_id=1234.5678&client_secret=synthetic-secret" \
                           "&code=synthetic-code&redirect_uri=https%3A%2F%2Fapp.example.test%2Fslack%2Fsign-in"
  end

  it "posts the refresh token grant" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(OpenIDConnectSpecSupport::TOKEN_RESPONSE)
    request = Slack::Api::OpenIDConnectToken.refresh(client_id: "1234.5678", client_secret: "synthetic-secret",
      refresh_token: "xoxe-1-synthetic-refresh")

    OpenIDConnectSpecSupport.token_less_client(transport).call(request)

    transport.requests.first.body.should eq "grant_type=refresh_token&client_id=1234.5678" \
                                            "&client_secret=synthetic-secret&refresh_token=xoxe-1-synthetic-refresh"
  end

  it "redacts the client secret and the authorization code" do
    request = OpenIDConnectSpecSupport.exchange

    request.inspect.should_not contain "synthetic-secret"
    request.inspect.should_not contain "synthetic-code"
    request.to_s.should_not contain "synthetic-code"
  end

  it "redacts the client secret and the refresh token" do
    request = Slack::Api::OpenIDConnectToken.refresh(client_id: "1234.5678", client_secret: "synthetic-secret",
      refresh_token: "xoxe-1-synthetic-refresh")

    request.inspect.should_not contain "synthetic-secret"
    request.inspect.should_not contain "xoxe-1-synthetic-refresh"
  end

  it "sends nothing when a field is blank" do
    transport = Slack::Testing::RecordingTransport.new
    request = Slack::Api::OpenIDConnectToken.new(client_id: " ", client_secret: "synthetic-secret",
      code: " ", redirect_uri: "https://app.example.test/slack/sign-in")

    error = expect_raises(Slack::UI::ValidationError) do
      OpenIDConnectSpecSupport.token_less_client(transport).call(request)
    end

    error.issues.map(&.code).should eq ["openid_connect_token.client_id.blank", "openid_connect_token.code.blank"]
    transport.requests.should be_empty
  end

  it "keeps the returned tokens as secrets" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(OpenIDConnectSpecSupport::TOKEN_RESPONSE)

    token = OpenIDConnectSpecSupport.token_less_client(transport).call(OpenIDConnectSpecSupport.exchange)

    token.access_token.value.should eq "xoxp-synthetic-sign-in"
    id_token = token.id_token.should_not be_nil
    id_token.value.should eq "synthetic.id.token"
    token.token_type.should eq "Bearer"
    token.refresh_token.should be_nil
    token.expires_in.should be_nil
    token.inspect.should_not contain "xoxp-synthetic-sign-in"
    token.inspect.should_not contain "synthetic.id.token"
  end

  it "reads the rotation fields when Slack sends them" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":true,"access_token":"xoxe.xoxp-synthetic","token_type":"Bearer",) +
                      %("id_token":"synthetic.id.token","refresh_token":"xoxe-1-synthetic-refresh","expires_in":43200}))

    token = OpenIDConnectSpecSupport.token_less_client(transport).call(OpenIDConnectSpecSupport.exchange)

    token.id_token.should_not be_nil
    refresh_token = token.refresh_token.should_not be_nil
    refresh_token.value.should eq "xoxe-1-synthetic-refresh"
    token.expires_in.should eq 43200
    token.inspect.should_not contain "xoxe-1-synthetic-refresh"
  end

  it "reads a refresh response without an ID token" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":true,"access_token":"xoxe.xoxp-synthetic","token_type":"Bearer",) +
                      %("refresh_token":"xoxe-1-synthetic-refresh","expires_in":43200}))

    token = OpenIDConnectSpecSupport.token_less_client(transport).call(OpenIDConnectSpecSupport.exchange)

    token.id_token.should be_nil
    token.access_token.value.should eq "xoxe.xoxp-synthetic"
  end

  it "raises the Slack error for a rejected code" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":false,"error":"invalid_code"}))

    error = expect_raises(Slack::Api::Error) do
      OpenIDConnectSpecSupport.token_less_client(transport).call(OpenIDConnectSpecSupport.exchange)
    end

    error.code.should eq "invalid_code"
  end
end

describe Slack::Api::OpenIDConnectUserInfo do
  it "reads the signed-in user with the user token" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(OpenIDConnectSpecSupport::USER_INFO_RESPONSE)
    client = Slack::Api::Client.new(token: "xoxp-synthetic", transport: transport)

    info = client.call(Slack::Api::OpenIDConnectUserInfo.new)

    request = transport.requests.first
    request.uri.to_s.should eq "https://slack.com/api/openid.connect.userInfo"
    request.headers["Authorization"].should eq "Bearer xoxp-synthetic"
    request.body.should eq ""
    info.sub.should eq "U-SYNTHETIC"
    info.user_id.should eq "U-SYNTHETIC"
    info.team_id.should eq "T-SYNTHETIC"
    info.email.should eq "alice@example.test"
    info.email_verified?.should be_true
    info.date_email_verified.should eq 1622128723
    info.name.should eq "alice"
    info.given_name.should eq "Alice"
    info.family_name.should eq "Example"
    info.locale.should eq "en-US"
    info.picture.should eq "https://images.example.test/alice.png"
    info.team_name.should eq "Example Team"
    info.team_domain.should eq "example-team"
    info.user_image_24.should eq "https://images.example.test/24.png"
    info.user_image_512.should eq "https://images.example.test/512.png"
    info.team_image_34.should eq "https://images.example.test/t34.png"
    info.team_image_230.should eq "https://images.example.test/t230.png"
    info.team_image_default?.should be_true
  end

  it "reads a response without the optional profile fields" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":true,"sub":"U-SYNTHETIC","https://slack.com/user_id":"U-SYNTHETIC",) +
                      %("https://slack.com/team_id":"T-SYNTHETIC"}))
    client = Slack::Api::Client.new(token: "xoxp-synthetic", transport: transport)

    info = client.call(Slack::Api::OpenIDConnectUserInfo.new)

    info.email.should be_nil
    info.email_verified?.should be_nil
    info.team_image_default?.should be_nil
  end
end
