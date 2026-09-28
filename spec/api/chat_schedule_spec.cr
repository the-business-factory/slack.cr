require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ChatScheduleMessage do
  it "schedules blocks in a thread with Unix seconds and reads the scheduled message" do
    message = Slack::UI.message(fallback_text: "Standup in 5 minutes") do |builder|
      builder.section(Slack::UI.mrkdwn("*Standup* in 5 minutes"))
    end
    request = Slack::Api::ChatScheduleMessage.new(
      channel: "C123ABC456", post_at: Time.unix(1_562_180_400), message: message,
      attachments: [Slack::UI::Attachment.new(text: "Room 4", fallback: "Room 4")],
      thread_ts: "1562180000.000100", reply_broadcast: true,
      parse: Slack::Api::ChatPostMessage::Parse::None, link_names: false,
      unfurl_links: false, unfurl_media: true, as_user: false)
    expected = JSON.parse(<<-JSON)
      {"channel":"C123ABC456","post_at":1562180400,"text":"Standup in 5 minutes",
       "blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*Standup* in 5 minutes"}}],
       "attachments":[{"fallback":"Room 4","text":"Room 4"}],
       "thread_ts":"1562180000.000100","reply_broadcast":true,"parse":"none","link_names":false,
       "unfurl_links":false,"unfurl_media":true,"as_user":false}
      JSON
    WebMock.stub(:post, "https://slack.com/api/chat.scheduleMessage").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
      HTTP::Client::Response.new(200, body: <<-JSON)
        {"ok":true,"channel":"C123ABC456","scheduled_message_id":"Q1298393284","post_at":"1562180400",
         "message":{"text":"Standup in 5 minutes","bot_id":"B123ABC456","type":"delayed_message","subtype":"bot_message"}}
        JSON
    end

    response = ApiSupport.client.call(request)

    response.channel.should eq "C123ABC456"
    response.scheduled_message_id.should eq "Q1298393284"
    response.post_at.should eq Time.unix(1_562_180_400)
    response.message.should_not(be_nil)["type"].as_s.should eq "delayed_message"
  end

  it "schedules markdown_text and reads an integer post_at" do
    request = Slack::Api::ChatScheduleMessage.new(channel: "C1", post_at: Time.unix(1_700_000_000),
      markdown_text: "**Reminder**")
    WebMock.stub(:post, "https://slack.com/api/chat.scheduleMessage").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected JSON body"))
        .should eq JSON.parse(%({"channel":"C1","post_at":1700000000,"markdown_text":"**Reminder**"}))
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C1","scheduled_message_id":"Q1","post_at":1700000000}))
    end

    ApiSupport.client.call(request).post_at.should eq Time.unix(1_700_000_000)
  end

  it "rejects a blank channel and a broadcast without a thread before transport" do
    request = Slack::Api::ChatScheduleMessage.new(channel: " ", post_at: Time.unix(1_700_000_000),
      text: "Hi", reply_broadcast: true)

    expect_raises(Slack::UI::ValidationError) { ApiSupport.client.call(request) }
      .issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"chat_schedule_message.channel.blank", "channel"},
      {"chat_schedule_message.reply_broadcast.thread_required", "reply_broadcast"},
    ]
  end

  it "raises time_in_past as the error code" do
    WebMock.stub(:post, "https://slack.com/api/chat.scheduleMessage")
      .to_return(body: %({"ok":false,"error":"time_in_past"}))
    request = Slack::Api::ChatScheduleMessage.new(channel: "C1", post_at: Time.unix(1), text: "Late")

    expect_raises(Slack::Api::Error) { ApiSupport.client.call(request) }.code.should eq "time_in_past"
  end
end

describe Slack::Api::ChatDeleteScheduledMessage do
  it "deletes one scheduled message" do
    WebMock.stub(:post, "https://slack.com/api/chat.deleteScheduledMessage").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected JSON body"))
        .should eq JSON.parse(%({"channel":"C123ABC456","scheduled_message_id":"Q1234ABCD","as_user":true}))
      HTTP::Client::Response.new(200, body: %({"ok":true}))
    end
    request = Slack::Api::ChatDeleteScheduledMessage.new(channel: "C123ABC456",
      scheduled_message_id: "Q1234ABCD", as_user: true)

    ApiSupport.client.call(request).ok?.should be_true
  end

  it "rejects a blank scheduled message ID before transport" do
    Slack::Api::ChatDeleteScheduledMessage.new(channel: "C1", scheduled_message_id: "").validate
      .map(&.code).should eq ["chat_delete_scheduled_message.scheduled_message_id.blank"]
  end
end

describe Slack::Api::ChatScheduledMessagesList do
  it "reads every page of scheduled messages in a time range" do
    WebMock.stub(:post, "https://slack.com/api/chat.scheduledMessages.list")
      .with(body: "channel=C1H9RESGL&latest=1552000000&oldest=1551000000&team_id=T123&limit=1",
        headers: {"Content-Type" => "application/x-www-form-urlencoded"})
      .to_return(body: <<-JSON)
        {"ok":true,"scheduled_messages":[{"id":"Q1298393284","channel_id":"C1H9RESGL",
         "post_at":1551991428,"date_created":1551891734,"text":"Here's a message for you in the future"}],
         "response_metadata":{"next_cursor":"dGVhbTpDMUg5UkVTR0w="}}
        JSON
    WebMock.stub(:post, "https://slack.com/api/chat.scheduledMessages.list")
      .with(body: "channel=C1H9RESGL&latest=1552000000&oldest=1551000000&team_id=T123&cursor=dGVhbTpDMUg5UkVTR0w%3D&limit=1")
      .to_return(body: <<-JSON)
        {"ok":true,"scheduled_messages":[{"id":1298393285,"channel_id":"C1H9RESGL",
         "post_at":1551995000,"date_created":1551891800}],"response_metadata":{"next_cursor":""}}
        JSON
    request = Slack::Api::ChatScheduledMessagesList.new(channel: "C1H9RESGL",
      latest: Time.unix(1_552_000_000), oldest: Time.unix(1_551_000_000), team_id: "T123", limit: 1)

    messages = [] of Slack::Models::Chat::ScheduledMessage
    ApiSupport.client.each_page(request) { |page| messages.concat(page.model.scheduled_messages) }

    messages.map(&.id).should eq ["Q1298393284", "1298393285"]
    first = messages.first
    first.channel_id.should eq "C1H9RESGL"
    first.post_at.should eq Time.unix(1_551_991_428)
    first.date_created.should eq Time.unix(1_551_891_734)
    first.text.should eq "Here's a message for you in the future"
    messages.last.text.should be_nil
  end

  it "rejects a limit outside the pagination range" do
    Slack::Api::ChatScheduledMessagesList.new(limit: 0).validate.map(&.code)
      .should eq ["pagination.limit.out_of_range"]
  end
end
