require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Saves a message for a user: links to it in an ephemeral thread reply that only
# the user sees, and schedules a reminder for the next day.
module OfflineEphemeralReplyExample
  alias UI = Slack::UI

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-ephemeral", transport: OfflineExample::WebMockTransport.new)
    stub_responses(output)

    channel, saved_ts, user = "C123", "1710000000.000100", "U123"
    link = client.call(Slack::Api::ChatGetPermalink.new(channel: channel, message_ts: saved_ts)).permalink
    reply = UI.message(fallback_text: "Saved for later") do |builder|
      builder.section(UI.mrkdwn("Saved <#{link}|this message>. I will remind you tomorrow."))
    end
    ephemeral = client.call(Slack::Api::ChatPostEphemeral.new(
      channel: channel, user: user, message: reply, thread_ts: saved_ts))
    reminder = client.call(Slack::Api::ChatScheduleMessage.new(
      channel: "D123", post_at: Time.unix(1_710_086_400), text: "Reminder: <#{link}|saved message>"))
    output.puts "Ephemeral #{ephemeral.message_ts}; reminder #{reminder.scheduled_message_id} at #{reminder.post_at.to_unix}"
  end

  private def self.stub_responses(output : IO) : Nil
    WebMock.stub(:post, "https://slack.com/api/chat.getPermalink")
      .to_return(body: %({"ok":true,"channel":"C123","permalink":"https://example.slack.com/archives/C123/p1710000000000100"}))
    WebMock.stub(:post, "https://slack.com/api/chat.postEphemeral").to_return do |request|
      output.puts request.body
      HTTP::Client::Response.new(200, body: %({"ok":true,"message_ts":"1710000050.000200"}))
    end
    WebMock.stub(:post, "https://slack.com/api/chat.scheduleMessage").to_return do |request|
      output.puts request.body
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"D123","scheduled_message_id":"Q0REMIND1","post_at":"1710086400"}))
    end
  end
end
