require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ChatPostEphemeral do
  it "posts blocks, an attachment, and every option to one user" do
    message = Slack::UI.message(fallback_text: "Only you can see this") do |builder|
      builder.section(Slack::UI.mrkdwn("Your export is *ready*"), block_id: "export")
    end
    attachment = Slack::UI::Attachment.new(fallback: "Export details", text: "3 files",
      color: Slack::UI::Attachment::Color.good)
    request = Slack::Api::ChatPostEphemeral.new(
      channel: "C0EXPORT1", user: "U0ASKER1", message: message, attachments: [attachment],
      thread_ts: "1710000000.000100", parse: Slack::Api::ChatPostMessage::Parse::None,
      link_names: true, username: "Exporter", icon: Slack::UI::Icon::Emoji.new(":package:"),
      as_user: false)
    expected = JSON.parse(<<-JSON)
      {"channel":"C0EXPORT1","user":"U0ASKER1","text":"Only you can see this",
       "blocks":[{"type":"section","block_id":"export","text":{"type":"mrkdwn","text":"Your export is *ready*"}}],
       "attachments":[{"color":"good","fallback":"Export details","text":"3 files"}],
       "thread_ts":"1710000000.000100","parse":"none","link_names":true,
       "username":"Exporter","icon_emoji":":package:","as_user":false}
      JSON
    WebMock.stub(:post, "https://slack.com/api/chat.postEphemeral")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic-ephemeral", "Content-Type" => "application/json; charset=utf-8"})
      .to_return do |http_request|
        JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
        HTTP::Client::Response.new(200, body: %({"ok":true,"message_ts":"1502210682.580145"}))
      end

    response = ApiSupport.client("xoxb-synthetic-ephemeral").call(request)

    response.message_ts.should eq "1502210682.580145"
  end

  it "posts markdown_text with an icon URL" do
    request = Slack::Api::ChatPostEphemeral.new(channel: "C1", user: "U1",
      markdown_text: "**Heads up**", icon: Slack::UI::Icon::Url.new("https://example.com/icon.png"))

    JSON.parse(request.to_json).should eq JSON.parse(
      %({"channel":"C1","user":"U1","markdown_text":"**Heads up**","icon_url":"https://example.com/icon.png"}))
  end

  it "rejects a blank user, a malformed thread, and too many attachments before HTTP" do
    attachments = Array.new(101) { Slack::UI::Attachment.new(fallback: "x") }
    request = Slack::Api::ChatPostEphemeral.new(channel: " ", user: "", text: "Hi",
      thread_ts: "1710000000", attachments: attachments, username: " ")

    error = expect_raises(Slack::UI::ValidationError) { ApiSupport.client.call(request) }

    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"chat_post_ephemeral.attachments.too_many", "attachments"},
      {"chat_post_ephemeral.channel.blank", "channel"},
      {"chat_post_ephemeral.user.blank", "user"},
      {"chat_post_ephemeral.thread_ts.invalid", "thread_ts"},
      {"chat_post_ephemeral.username.blank", "username"},
    ]
  end

  it "raises the Slack error code when the user cannot see the message" do
    WebMock.stub(:post, "https://slack.com/api/chat.postEphemeral")
      .to_return(body: %({"ok":false,"error":"user_not_in_channel"}))
    request = Slack::Api::ChatPostEphemeral.new(channel: "C1", user: "U1", text: "Hi")

    expect_raises(Slack::Api::Error) { ApiSupport.client.call(request) }.code.should eq "user_not_in_channel"
  end
end
