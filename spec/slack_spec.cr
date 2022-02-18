require "./spec_helper"

def build_http_request(headers, body)
  HTTP::Request.new(
    "POST",
    "/webhook_url",
    headers: headers,
    body: body
  )
end

def build_request(namespace, name)
  headers, event = request_data(namespace, name)
  build_http_request(headers, event)
end

def build_request(namespace)
  headers, event = request_data(namespace)
  build_http_request(headers, event)
end

def load_event(event_namespace, name)
  File.read("spec/fixtures/events/#{event_namespace}/#{name}.json")
end

def load_event(name)
  File.read("spec/fixtures/events/#{name}.json")
end

def build_headers_and_body(body)
  headers = HTTP::Headers.new
  timestamp = 1.minutes.ago.to_unix.to_s
  signature = Slack::Webhooks::Signature.new(timestamp, body).compute
  headers["X-Slack-Request-Timestamp"] = timestamp
  headers["X-Slack-Signature"] = signature
  {headers, body}
end

def request_data(event_namespace, name) : Tuple(HTTP::Headers, String)
  event = load_event(event_namespace, name)
  build_headers_and_body(event)
end

def request_data(event_namespace) : Tuple(HTTP::Headers, String)
  event = load_event(event_namespace)
  build_headers_and_body(event)
end

describe Slack do
  context "replay attack attempt" do
    it "prevents replay attacks" do
      headers = HTTP::Headers.new
      headers["X-Slack-Request-Timestamp"] = 10.minutes.ago.to_unix.to_s
      headers["X-Slack-Signature"] = "signature"
      event = load_event("message")
      request = HTTP::Request.new(
        "POST",
        "/webhook_url",
        headers: headers,
        body: event
      )

      expect_raises(Slack::Webhooks::VerifiedRequest::ReplayAttackError) do
        Slack.process_request(request)
      end
    end
  end

  context "unverified events" do
    it "does not process unverified events" do
      headers = HTTP::Headers.new
      timestamp = 1.minutes.ago.to_unix.to_s
      event = load_event("message", "message_changed")
      signature = "signaturewillnotmatch"
      headers["X-Slack-Request-Timestamp"] = timestamp
      headers["X-Slack-Signature"] = signature

      request = HTTP::Request.new(
        "POST",
        "/webhook_url",
        headers: headers,
        body: event
      )

      expect_raises(Slack::Webhooks::VerifiedRequest::SignatureMismatchError) do
        Slack.process_request(request)
      end
    end
  end

  context "message events" do
    it "handles message_deleted events" do
      request = build_request("message", "message_deleted")
      event = Slack.process_request(request).as(Slack::VerifiedEvent).event
      event.is_a?(Slack::Events::Message::MessageDeleted).should be_true
    end

    it "handles message_changed events" do
      request = build_request("message", "message_changed")
      event = Slack.process_request(request).as(Slack::VerifiedEvent).event
      event.is_a?(Slack::Events::Message::MessageChanged).should be_true
    end

    it "handles new message events (no subtype)" do
      request = build_request("message")
      event = Slack
        .process_request(request)
        .as(Slack::VerifiedEvent)
        .event
        .as(Slack::Events::Message)

      event.text.should match /testing multiple repeated links/
    end

    it "handles bot add events" do
      request = build_request("message", "bot_add")
      event = Slack.process_request(request).as(Slack::VerifiedEvent).event
      event.is_a?(Slack::Events::Message::BotAdd).should be_true
    end

    it "handles channel join events" do
      request = build_request("message", "channel_join")
      event = Slack.process_request(request).as(Slack::VerifiedEvent).event
      event.is_a?(Slack::Events::Message::ChannelJoin).should be_true
    end
  end

  describe "#to_json" do
    it "should build a JSON string for the data in the payload" do
      request = build_request("reaction_removed")
      # This is a subset of the full event body, so this mostly ensures that
      # all JSON converters are properly implementing from_json and to_json.
      expected_json = <<-JSON
      {
        "api_app_id": "A031L6N0Q3G",
        "authorizations": [
          {
            "is_bot": true,
            "team_id": "T017GL5AV5E",
            "user_id": "U0325FAKTL1",
            "enterprise_id": null,
            "is_enterprise_install": false
          }
        ],
        "event": {
          "type": "reaction_removed",
          "item": {
            "ts": "1644728351.305109",
            "type": "message",
            "channel": "C016U8H75V1"
          },
          "item_user": "U016SQZLFEE",
          "reaction": "100",
          "user": "U016SQZLFEE",
          "event_ts": "1644729352.000000"
        },
        "event_context": "4-eyJldCI6InJlYWN0aW9uX3JlbW92ZWQiLCJ0aWQiOiJUMDE3R0w1QVY1RSIsImFpZCI6IkEwMzFMNk4wUTNHIiwiY2lkIjoiQzAxNlU4SDc1VjEifQ",
        "event_id": "Ev032V4P2GQ3",
        "team_id": "T017GL5AV5E",
        "token": "E6FV7uzAaZoqjhbU56ZKNnIk",
        "type": "event_callback",
        "event_time": 1644729352
      }
      JSON
      json = Slack.process_request(request).to_pretty_json
      json.should eq expected_json
    end
  end

  it "should handle removed reactions" do
    request = build_request("reaction_removed")
    event = Slack.process_request(request).as(Slack::VerifiedEvent).event
    event.is_a?(Slack::Events::ReactionRemoved).should be_true
  end

  it "should handle added reactions" do
    request = build_request("reaction_added")
    event = Slack.process_request(request).as(Slack::VerifiedEvent).event
    event.is_a?(Slack::Events::ReactionAdded).should be_true
  end

  it "should handle app uninstalled events" do
    request = build_request("app_uninstalled")
    event = Slack.process_request(request).as(Slack::VerifiedEvent).event
    event.is_a?(Slack::Events::AppUninstalled).should be_true
  end

  it "should handle app_home_opened events" do
    request = build_request("app_home_opened")

    event = Slack
      .process_request(request)
      .as(Slack::VerifiedEvent)
      .event
      .as(Slack::Events::AppHomeOpened)

    event.tab.should eq "home"
    event.type.should eq "app_home_opened"
  end

  it "should handle token revoked events" do
    request = build_request("tokens_revoked")
    event = Slack.process_request(request).as(Slack::VerifiedEvent).event
    event.is_a?(Slack::Events::TokensRevoked).should be_true
  end

  it "should handle url verification events" do
    request = build_request("url_verification")
    event = Slack.process_request(request).as(Slack::UrlVerificationEvent)
    expected_json = {
      "challenge" => "3eZbrw1aBm2rZgRNFdxV2595E9CY3gmdALWMmHkvFXO7tYXAYM8P",
    }.to_json
    event.response.to_json.should eq expected_json
  end
end
