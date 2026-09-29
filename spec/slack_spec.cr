require "./spec_helper"

# Signature and replay checks are in spec/webhooks/signature_spec.cr, and the
# decoded type of each fixture is in spec/decoder_contract_spec.cr.
module SlackSpec
  def self.event(fixture : String) : Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited
    Slack::Events.parse(File.read("spec/fixtures/events/#{fixture}.json"))
  end

  def self.command(fixture : String) : Slack::Command
    Slack::Commands.parse(File.read("spec/fixtures/commands/#{fixture}.txt"))
  end
end

describe Slack do
  context "message events" do
    it "should handle thread_broadcast events" do
      event = SlackSpec.event("thread_broadcast").should be_a Slack::VerifiedEvent
      nested = event.event.should be_a Slack::Events::Message::ThreadBroadcast
      nested.subtype.should eq "thread_broadcast"
      nested.root["thread_ts"].should eq nested.thread_ts
    end

    it "handles new message events (no subtype)" do
      event = SlackSpec.event("message").should be_a Slack::VerifiedEvent
      nested_event = event.event.should be_a Slack::Events::Message
      nested_event.text.should match /testing multiple repeated links/
    end
  end

  describe "#to_json" do
    it "should build a JSON string for the data in the payload" do
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
            "event_ts": "1644729352.000400"
          },
          "event_context": "4-eyJldCI6InJlYWN0aW9uX3JlbW92ZWQiLCJ0aWQiOiJUMDE3R0w1QVY1RSIsImFpZCI6IkEwMzFMNk4wUTNHIiwiY2lkIjoiQzAxNlU4SDc1VjEifQ",
          "event_id": "Ev032V4P2GQ3",
          "team_id": "T017GL5AV5E",
          "token": "E6FV7uzAaZoqjhbU56ZKNnIk",
          "type": "event_callback",
          "is_ext_shared_channel": false,
          "event_time": 1644729352
        }
        JSON
      json = SlackSpec.event("reaction_removed").to_pretty_json
      json.should eq expected_json
    end
  end

  it "should handle app_home_opened events" do
    event = SlackSpec.event("app_home_opened").should be_a Slack::VerifiedEvent
    nested_event = event.event.should be_a Slack::Events::AppHomeOpened
    nested_event.tab.should eq "home"
    nested_event.type.should eq "app_home_opened"
  end

  it "should handle url verification events" do
    event = SlackSpec.event("url_verification").should be_a Slack::UrlVerification
    expected_json = {
      "challenge" => "3eZbrw1aBm2rZgRNFdxV2595E9CY3gmdALWMmHkvFXO7tYXAYM8P",
    }.to_json
    event.response.to_json.should eq expected_json
  end

  it "should handle slack commands with encoded names" do
    command = SlackSpec.command("encoded_names")
    command.decoded_usernames.first.id.should eq "U016RDVB4Q5"
    command.decoded_usernames.first.name.should eq "username.with.spaces"
    command.decoded_channels[0].id.should eq "C016C36NRKR"
    command.decoded_channels[0].name.should eq "tools"
    command.decoded_channels[1].id.should eq "C01702XL4TE"
    command.decoded_channels[1].name.should eq "customer-development"
    command.plaintext_channels.should be_empty
    command.plaintext_usernames.should be_empty
  end

  it "should handle slack commands with unencoded names" do
    command = SlackSpec.command("unencoded_names")
    command.plaintext_usernames[0].name.should eq "username.with.spaces"
    command.plaintext_usernames[1].name.should eq "robcole"
    command.plaintext_channels[0].name.should eq "tools"
    command.decoded_usernames.should be_empty
    command.decoded_channels.should be_empty
  end
end
