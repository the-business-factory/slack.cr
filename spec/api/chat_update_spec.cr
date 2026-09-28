require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ChatUpdate do
  it "replaces the message snapshot once and parses the update response" do
    elements = [Slack::UI::BlockElements::Button.new(
      text: Slack::UI.plain("Details", emoji: false), action_id: "details", value: "42")]
    builder = Slack::UI::MessageBuilder.new(fallback_text: "Request 42 approved.")
    builder.section(Slack::UI.mrkdwn("*Approved*", verbatim: false), block_id: "status.v2")
    builder.actions(elements: elements, block_id: "controls.v2")
    message = builder.build
    client = ApiSupport.client("xoxb-synthetic-update")
    request = Slack::Api::ChatUpdate.new(channel: "C123", ts: "1710000000.000000001",
      message: message, as_user: true)
    elements.clear
    builder.divider
    message.blocks.each { |block| block.elements.clear if block.is_a?(Slack::UI::Blocks::Actions) }
    message.blocks.clear
    expected = JSON.parse(<<-JSON)
      {"channel":"C123","ts":"1710000000.000000001","text":"Request 42 approved.","blocks":[
        {"type":"section","block_id":"status.v2","text":{"type":"mrkdwn","text":"*Approved*","verbatim":false}},
        {"type":"actions","block_id":"controls.v2","elements":[{"type":"button","text":{"type":"plain_text","text":"Details","emoji":false},"action_id":"details","value":"42"}]}
      ],"as_user":true}
      JSON
    JSON.parse(request.to_json).should eq expected
    count = 0
    WebMock.stub(:post, "https://slack.com/api/chat.update")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic-update", "Content-Type" => "application/json; charset=utf-8"})
      .to_return do |http_request|
        count += 1
        JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
        HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C123","ts":"1710000000.000000001","text":"Request 42 approved.","message":{"text":"Request 42 approved.","user":"U123","future":true}}))
      end
    response = client.call(request)
    response.should be_a(Slack::Models::Chat::UpdateMessage)
    response.ok?.should be_true
    response.channel.should eq "C123"
    response.ts.should eq "1710000000.000000001"
    response.text.should eq "Request 42 approved."
    response.message.should_not(be_nil)["future"].as_bool.should be_true
    count.should eq 1
  end

  it "rejects invalid identifiers and unsupported fallback before transport" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/chat.update").to_return do |_request|
      requests += 1
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C123","ts":"1.1","text":"Done"}))
    end
    explicit = Slack::UI.message(fallback_text: "Done", &.divider)
    generated = Slack::UI.message_with_slack_generated_fallback(&.divider)
    overlong = Slack::UI.message(fallback_text: "é" * 4001, &.divider)
    {
      {"", "1.1", explicit, "chat_update.channel.blank", "channel"},
      {"  ", "1.1", explicit, "chat_update.channel.blank", "channel"},
      {"C123", "", explicit, "chat_update.ts.invalid", "ts"},
      {"C123", "1710000000", explicit, "chat_update.ts.invalid", "ts"},
      {"C123", "1.2e3", explicit, "chat_update.ts.invalid", "ts"},
      {"C123", "1.1", generated, "chat_update.text.required", "text"},
      {"C123", "1.1", overlong, "chat_update.text.too_long", "text"},
    }.each do |channel, timestamp, message, code, path|
      client = ApiSupport.client("xoxb-synthetic-invalid")
      request = Slack::Api::ChatUpdate.new(channel: channel, ts: timestamp,
        message: message)
      error = expect_raises(Slack::UI::ValidationError) { client.call(request) }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{code, path}]
      expect_raises(Slack::UI::ValidationError) { request.to_json }
    end
    requests.should eq 0
  end

  [nil, false].each do |as_user|
    it "preserves as_user #{as_user.inspect} and omits unsupported fields" do
      message = Slack::UI.message(fallback_text: "Done", &.divider)
      client = ApiSupport.client("xoxb-synthetic-minimal")
      request = Slack::Api::ChatUpdate.new(channel: "D123", ts: "1.1",
        message: message, as_user: as_user)
      expected = JSON.parse(as_user.nil? ? %({"channel":"D123","ts":"1.1","text":"Done","blocks":[{"type":"divider"}]}) : %({"channel":"D123","ts":"1.1","text":"Done","blocks":[{"type":"divider"}],"as_user":false}))
      WebMock.stub(:post, "https://slack.com/api/chat.update").to_return do |http_request|
        JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
        HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"D123","ts":"1.1","text":"Done"}))
      end
      client.call(request).message.should be_nil
    end
  end

  it "accepts 4000 fallback characters without a byte-based limit" do
    fallback = "é" * 4000
    message = Slack::UI.message(fallback_text: fallback, &.divider)
    client = ApiSupport.client("xoxb-synthetic-limit")
    request = Slack::Api::ChatUpdate.new(channel: "C123", ts: "1.1", message: message)
    WebMock.stub(:post, "https://slack.com/api/chat.update").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected JSON body"))["text"].as_s.should eq fallback
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C123","ts":"1.1","text":"Done"}))
    end
    client.call(request).ok?.should be_true
  end

  it "raises the Slack error code when Slack refuses the update" do
    count = 0
    WebMock.stub(:post, "https://slack.com/api/chat.update").to_return do |_request|
      count += 1
      HTTP::Client::Response.new(200, body: %({"ok":false,"error":"cant_update_message"}))
    end
    client = ApiSupport.client("xoxb-synthetic-denied")
    request = Slack::Api::ChatUpdate.new(channel: "C123", ts: "1.1",
      message: Slack::UI.message(fallback_text: "Done", &.divider))
    expect_raises(Slack::Api::Error) { client.call(request) }.code.should eq "cant_update_message"
    count.should eq 1
  end

  it "updates text, attachments, metadata, files, and options" do
    attachment = Slack::UI::Attachment.new(fallback: "Build 7", text: "All checks passed",
      color: Slack::UI::Attachment::Color.hex("#2EB886"))
    file_ids = ["F0REPORT1", "F0REPORT2"]
    request = Slack::Api::ChatUpdate.new(channel: "C123", ts: "1710000000.000200",
      text: "Build 7 passed", attachments: [attachment], file_ids: file_ids,
      metadata: Slack::UI::MessageMetadata.new("build_finished", {"build" => JSON::Any.new("7")}),
      parse: Slack::Api::ChatPostMessage::Parse::Full, link_names: true, reply_broadcast: true)
    file_ids << "F0LATE"
    expected = JSON.parse(<<-JSON)
      {"channel":"C123","ts":"1710000000.000200","text":"Build 7 passed",
       "attachments":[{"color":"#2EB886","fallback":"Build 7","text":"All checks passed"}],
       "metadata":{"event_type":"build_finished","event_payload":{"build":"7"}},
       "parse":"full","link_names":true,"reply_broadcast":true,"file_ids":["F0REPORT1","F0REPORT2"]}
      JSON
    WebMock.stub(:post, "https://slack.com/api/chat.update").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C123","ts":"1710000000.000200","text":"Build 7 passed"}))
    end

    ApiSupport.client.call(request).text.should eq "Build 7 passed"
    request.file_ids.should eq ["F0REPORT1", "F0REPORT2"]
  end

  it "updates markdown_text and removes attachments with an empty list" do
    request = Slack::Api::ChatUpdate.new(channel: "C123", ts: "1.1", markdown_text: "**Done**",
      attachments: [] of Slack::UI::Attachment)

    JSON.parse(request.to_json).should eq JSON.parse(
      %({"channel":"C123","ts":"1.1","markdown_text":"**Done**","attachments":[]}))
  end

  it "rejects text over 4000 characters and empty markdown before transport" do
    Slack::Api::ChatUpdate.new(channel: "C1", ts: "1.1", text: "a" * 4001).validate.map(&.code)
      .should eq ["chat_update.text.too_long"]
    Slack::Api::ChatUpdate.new(channel: "C1", ts: "1.1", markdown_text: "").validate.map(&.code)
      .should eq ["chat_update.markdown_text.empty"]
  end

  {"message_not_found", "edit_window_closed", "streaming_state_conflict"}.each do |code|
    it "raises #{code} as the error code" do
      WebMock.stub(:post, "https://slack.com/api/chat.update")
        .to_return(body: %({"ok":false,"error":"#{code}"}))
      request = Slack::Api::ChatUpdate.new(channel: "C1", ts: "1.1", text: "Edited")

      expect_raises(Slack::Api::Error) { ApiSupport.client.call(request) }.code.should eq code
    end
  end
end
