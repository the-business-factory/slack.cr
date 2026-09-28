require "../spec_helper"
require "../../src/slack/testing"

private SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")

describe Slack::Testing::SignedRequest do
  it "builds a POST request that the verifier accepts with its exact body" do
    body = %({"type":"url_verification","challenge":"synthetic-challenge"})
    request = Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET)

    verified = Slack::Webhooks::Verifier.new(SIGNING_SECRET).verify(request)

    verified.body.should eq body
    request.method.should eq "POST"
    request.path.should eq "/slack/events"
    request.headers["Content-Type"].should eq "application/json"
  end

  it "signs the given timestamp, path, and content type" do
    body = "payload=%7B%22type%22%3A%22block_actions%22%7D"
    request = Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, timestamp: Time.unix(1_700_000_000),
      path: "/slack/interactions", content_type: "application/x-www-form-urlencoded")

    request.path.should eq "/slack/interactions"
    request.headers["Content-Type"].should eq "application/x-www-form-urlencoded"
    request.headers["X-Slack-Request-Timestamp"].should eq "1700000000"
    # Independently calculated with Python stdlib hmac/sha256 over
    # b'v0:1700000000:' + body.
    request.headers["X-Slack-Signature"].should eq "v0=3ef1cb6ad095ec52b1f6964c75573aaac6a3f0f6b62d79967aa1c096028b518f"
  end

  it "fails verification with a different signing secret" do
    request = Slack::Testing::SignedRequest.build("token=synthetic", signing_secret: Slack::Auth::Secret.new("other-secret"))

    expect_raises(Slack::Errors::SignatureMismatch) do
      Slack::Webhooks::Verifier.new(SIGNING_SECRET).verify(request)
    end
  end
end
