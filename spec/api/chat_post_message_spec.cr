require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ChatPostMessage do
  it "posts one structured message snapshot" do
    token = "xoxb-synthetic-post"
    message = sample_message("Result")

    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .with(headers: {"Authorization" => "Bearer #{token}", "Content-Type" => "application/json; charset=utf-8"})
      .to_return do |request|
        payload = JSON.parse(request.body || fail("Expected a JSON request body"))
        payload["channel"].as_s.should eq "C-POST"
        payload["text"].as_s.should eq "Result fallback"
        payload["blocks"][0]["text"]["text"].as_s.should eq "Result"
        payload["thread_ts"].as_s.should eq "1710000000.000001"
        payload["reply_broadcast"].as_bool.should be_false
        payload["unfurl_links"].as_bool.should be_false
        payload["unfurl_media"].as_bool.should be_false
        HTTP::Client::Response.new(
          200,
          body: File.read("spec/fixtures/api/chat-post-success-section.json")
        )
      end

    request = Slack::Api::ChatPostMessage.new(
      channel: "C-POST",
      message: message,
      thread_ts: "1710000000.000001",
      reply_broadcast: false,
      unfurl_links: false,
      unfurl_media: false
    )
    ApiSupport.client(token).call(request).ts.should eq "1652892819.911709"
  end

  it "posts a Message Input as a structured block with explicit false flags" do
    message = Slack::UI.message(fallback_text: "Note") do |builder|
      builder.input(label: Slack::UI.plain("Note"),
        element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "note", multiline: false),
        optional: false, dispatch_action: false)
    end
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic-input"})
      .to_return do |http_request|
        JSON.parse(http_request.body || fail("Expected JSON body")).should eq JSON.parse(<<-JSON)
          {"channel":"C-INPUT","text":"Note","blocks":[{"type":"input","label":{"type":"plain_text","text":"Note"},"element":{"type":"plain_text_input","action_id":"note","multiline":false},"optional":false,"dispatch_action":false}],"unfurl_links":false}
          JSON
        HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-post-success-section.json"))
      end
    request = Slack::Api::ChatPostMessage.new(
      channel: "C-INPUT", message: message, unfurl_links: false)
    ApiSupport.client("xoxb-synthetic-input").call(request)
  end

  it "parses a successful request through call" do
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .to_return(body: File.read("spec/fixtures/api/chat-post-success-section.json"))

    response = ApiSupport.client.call(Slack::Api::ChatPostMessage.new(
      channel: "C-CALL",
      message: sample_message("Call")
    ))

    response.should be_a(Slack::Models::Chat::PostMessage)
    response.ok?.should be_true
  end

  it "omits top-level text when Slack generates the accessibility fallback" do
    message = Slack::UI::Message.with_slack_generated_fallback(
      blocks: [Slack::UI::Blocks::Section.new(
        text: Slack::UI.plain("Derived")
      )]
    )
    request = Slack::Api::ChatPostMessage.new(
      channel: "C-DERIVED",
      message: message
    )

    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .to_return do |http_request|
        payload = JSON.parse(http_request.body || fail("Expected a JSON request body"))
        payload.as_h.has_key?("text").should be_false
        HTTP::Client::Response.new(
          200,
          body: File.read("spec/fixtures/api/chat-post-success-section.json")
        )
      end

    ApiSupport.client.call(request)
  end

  ["1710000000.000001", "1710000000.000000", "999999999.123456", "10000000000.123456", "1710000000.1", "1710000000.123456789"].each do |timestamp|
    it "preserves timestamp #{timestamp} and broadcasts" do
      requests = 0
      WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |http_request|
        requests += 1
        payload = JSON.parse(http_request.body || fail("Expected a JSON request body"))
        payload["thread_ts"].as_s.should eq timestamp
        payload["reply_broadcast"].as_bool.should be_true
        HTTP::Client::Response.new(
          200,
          body: File.read("spec/fixtures/api/chat-post-success-section.json")
        )
      end
      request = Slack::Api::ChatPostMessage.new(
        channel: "C-THREAD",
        message: sample_message("Thread"),
        thread_ts: timestamp,
        reply_broadcast: true
      )

      request.validate.should be_empty
      ApiSupport.client.call(request).ok?.should be_true
      requests.should eq 1
    end
  end

  [nil, false].each do |broadcast|
    it "omits an absent timestamp with reply_broadcast #{broadcast.inspect}" do
      requests = 0
      WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |http_request|
        requests += 1
        payload = JSON.parse(http_request.body || fail("Expected a JSON request body"))
        payload.as_h.has_key?("thread_ts").should be_false
        if broadcast.nil?
          payload.as_h.has_key?("reply_broadcast").should be_false
        else
          payload["reply_broadcast"].as_bool.should be_false
        end
        HTTP::Client::Response.new(
          200,
          body: File.read("spec/fixtures/api/chat-post-success-section.json")
        )
      end
      request = Slack::Api::ChatPostMessage.new(
        channel: "C-THREAD",
        message: sample_message("Thread"),
        reply_broadcast: broadcast
      )

      ApiSupport.client.call(request).ok?.should be_true
      requests.should eq 1
    end
  end

  ["", " ", "not-a-timestamp", "1710000000", "1710000000.", ".000001",
   "-1710000000.000001", "+1710000000.000001", "1.71e9", "1710000000..000001",
   " 1710000000.000001", "1710000000.000001\n", "１７１０００００００.000001"].each do |timestamp|
    it "rejects malformed timestamp #{timestamp.inspect} before HTTP" do
      requests = 0
      WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |_request|
        requests += 1
        HTTP::Client::Response.new(500)
      end

      [nil, false, true].each do |broadcast|
        request = Slack::Api::ChatPostMessage.new(
          channel: "C-THREAD",
          message: sample_message("Thread"),
          thread_ts: timestamp,
          reply_broadcast: broadcast
        )

        request.validate.map { |issue| {issue.code, issue.path} }.should eq [
          {"chat_post_message.thread_ts.invalid", "thread_ts"},
        ]
        error = expect_raises(Slack::UI::ValidationError) do
          ApiSupport.client.call(request)
        end
        error.issues.map { |issue| {issue.code, issue.path} }.should eq [
          {"chat_post_message.thread_ts.invalid", "thread_ts"},
        ]
        requests.should eq 0
      end
    end
  end

  it "rejects an empty channel before HTTP" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |_request|
      requests += 1
      HTTP::Client::Response.new(500)
    end
    request = Slack::Api::ChatPostMessage.new(
      channel: "",
      message: sample_message("Invalid")
    )

    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(request)
    end
    error.issues.map(&.code).should contain("chat_post_message.channel.empty")
    requests.should eq 0
  end

  it "requires a thread when reply_broadcast is true" do
    requests = 0
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |_request|
      requests += 1
      HTTP::Client::Response.new(500)
    end
    request = Slack::Api::ChatPostMessage.new(
      channel: "C-THREAD",
      message: sample_message("Thread"),
      reply_broadcast: true
    )

    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(request)
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"chat_post_message.reply_broadcast.thread_required", "reply_broadcast"},
    ]
    requests.should eq 0
  end

  it "owns a message snapshot separately from caller collections" do
    section = Slack::UI::Blocks::Section.new(
      text: Slack::UI.plain("Before")
    )
    blocks = [section]
    message = Slack::UI::Message.new(
      fallback_text: "Snapshot",
      blocks: blocks
    )
    request = Slack::Api::ChatPostMessage.new(
      channel: "C-SNAPSHOT",
      message: message
    )
    before = request.to_json

    blocks.clear
    message.blocks.clear

    request.to_json.should eq before
  end

  it "raises the Slack error code for a rejected message" do
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .to_return(body: %({"ok":false,"error":"invalid_blocks"}))

    error = expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ChatPostMessage.new(channel: "C-ERROR", message: sample_message("Error")))
    end
    error.code.should eq "invalid_blocks"
  end
end

private def sample_message(text : String) : Slack::UI::Message
  Slack::UI::Message.new(
    fallback_text: "#{text} fallback",
    blocks: [Slack::UI::Blocks::Section.new(
      text: Slack::UI.plain(text)
    )]
  )
end
