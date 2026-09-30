require "../spec_helper"
require "../../src/slack/testing"
require "../support/app/signed_request"

# Payloads are authored independently from https://docs.slack.dev/reference/events/message
# and https://docs.slack.dev/reference/events/member_joined_channel.
# Delivered for a user-token installation: no bot authorization, so only the
# app_id identifies the app's own message.
private OWN_MESSAGE = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","channel":"C-SYNTHETIC","user":"U-BOT","bot_id":"B-SYNTHETIC","app_id":"A-SYNTHETIC",
            "text":"Checklist for this posting","ts":"1789232400.000200","event_ts":"1789232400.000200","channel_type":"channel"},
   "type":"event_callback","event_id":"Ev-OWN","event_time":1789232400,
   "authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-INSTALLER","is_bot":false,"is_enterprise_install":false}]}
  JSON

# Older shape: no app_id, but the bot user is the author.
private OWN_MESSAGE_BY_USER = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","channel":"D-SYNTHETIC","user":"U-BOT","bot_id":"B-SYNTHETIC",
            "text":"What did you do yesterday?","ts":"1789232400.000300","event_ts":"1789232400.000300","channel_type":"im"},
   "type":"event_callback","event_id":"Ev-OWN-USER","event_time":1789232400,
   "authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
  JSON

private HUMAN_DM = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","channel":"D-SYNTHETIC","user":"U-SYNTHETIC",
            "text":"Shipped the deploy fix","ts":"1789232400.000400","event_ts":"1789232400.000400","channel_type":"im"},
   "type":"event_callback","event_id":"Ev-HUMAN","event_time":1789232400,
   "authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
  JSON

# An incoming webhook: bot_id, no app_id, a user that is not the bot user.
private WEBHOOK_MESSAGE = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","channel":"C-SYNTHETIC","user":"U-WEBHOOK","bot_id":"B-WEBHOOK",
            "text":"Build 812 passed","ts":"1789232400.000500","event_ts":"1789232400.000500","channel_type":"channel"},
   "type":"event_callback","event_id":"Ev-WEBHOOK","event_time":1789232400,
   "authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
  JSON

private OTHER_APP_MESSAGE = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","channel":"C-SYNTHETIC","user":"U-OTHER-BOT","bot_id":"B-OTHER","app_id":"A-OTHER",
            "text":"Ticket JIRA-12 created","ts":"1789232400.000600","event_ts":"1789232400.000600","channel_type":"channel"},
   "type":"event_callback","event_id":"Ev-OTHER","event_time":1789232400,
   "authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
  JSON

private BOT_JOINED = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"member_joined_channel","user":"U-BOT","channel":"C-SYNTHETIC","channel_type":"C",
            "team":"T-SYNTHETIC","inviter":"U-SYNTHETIC","event_ts":"1789232400.000700"},
   "type":"event_callback","event_id":"Ev-JOINED","event_time":1789232400,
   "authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
  JSON

private def build_app(seen : Channel(String), ignore_self : Bool = true) : Slack::App
  client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic"), transport: Slack::Testing::RecordingTransport.new)
  app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client), ignore_self: ignore_self)
  app.message { |ctx| seen.send("message #{ctx.event.ts} bot=#{ctx.bot_user_id}") }
  app.on_member_joined_channel { |ctx| seen.send("joined #{ctx.event.user}") }
  app
end

private def receive(app : Slack::App, body : String) : AppSupport::Reply
  AppSupport.run(Slack::App::HttpReceiver.new(app, AppSupport::VERIFIER), AppSupport.json(body))
end

# Returns what the listener saw, or nil when it did not run within 100 ms.
private def seen_within(seen : Channel(String)) : String?
  select
  when value = seen.receive then value
  when timeout(100.milliseconds) then nil
  end
end

describe Slack::App::IgnoreSelf do
  it "skips a message whose app_id is the envelope's api_app_id and still answers 200" do
    seen = Channel(String).new(1)
    receive(build_app(seen), OWN_MESSAGE).status.should eq 200
    seen_within(seen).should be_nil
  end

  it "skips a message whose user is the bot authorization user" do
    seen = Channel(String).new(1)
    receive(build_app(seen), OWN_MESSAGE_BY_USER).status.should eq 200
    seen_within(seen).should be_nil
  end

  it "passes a human message and gives the bot user ID on the context" do
    seen = Channel(String).new(1)
    receive(build_app(seen), HUMAN_DM).status.should eq 200
    seen_within(seen).should eq "message 1789232400.000400 bot=U-BOT"
  end

  it "passes an incoming webhook message and another app's message" do
    seen = Channel(String).new(2)
    app = build_app(seen)
    receive(app, WEBHOOK_MESSAGE)
    receive(app, OTHER_APP_MESSAGE)
    # Each listener runs in its own fiber, so the two can finish in either order.
    [seen_within(seen), seen_within(seen)].compact.sort!.should eq [
      "message 1789232400.000500 bot=U-BOT",
      "message 1789232400.000600 bot=U-BOT",
    ]
  end

  it "does not filter member_joined_channel for the bot user" do
    seen = Channel(String).new(1)
    receive(build_app(seen), BOT_JOINED).status.should eq 200
    seen_within(seen).should eq "joined U-BOT"
  end

  it "passes the app's own message when ignore_self is false" do
    seen = Channel(String).new(1)
    receive(build_app(seen, ignore_self: false), OWN_MESSAGE).status.should eq 200
    seen_within(seen).should eq "message 1789232400.000200 bot="
  end
end
