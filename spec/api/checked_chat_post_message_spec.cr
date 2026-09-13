require "../spec_helper"

describe Slack::Api::CheckedChatPostMessage do
  it "posts one structured checked snapshot through result" do
    token = "xoxb-synthetic-checked"
    message = checked_message("Result")

    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .with(headers: {"Authorization" => "Bearer #{token}"})
      .to_return do |request|
        payload = JSON.parse(request.body || fail("Expected a JSON request body"))
        payload["channel"].as_s.should eq "C-CHECKED"
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

    request = Slack::Api::CheckedChatPostMessage.new(
      token: token,
      channel: "C-CHECKED",
      message: message,
      thread_ts: "1710000000.000001",
      reply_broadcast: false,
      unfurl_links: false,
      unfurl_media: false
    )
    request.result.status_code.should eq 200
  end

  it "parses a successful checked request through call" do
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .to_return(body: File.read("spec/fixtures/api/chat-post-success-section.json"))

    response = Slack::Api::CheckedChatPostMessage.new(
      token: "xoxb-synthetic-call",
      channel: "C-CALL",
      message: checked_message("Call")
    ).call

    response.should be_a(Slack::Models::Chat::PostMessage)
    response.ok?.should be_true
  end

  it "omits top-level text when Slack generates the accessibility fallback" do
    message = Slack::UI::Checked::Message.with_slack_generated_fallback(
      blocks: [Slack::UI::Checked::Blocks::Section.new(
        text: Slack::UI::Checked.plain("Derived")
      )]
    )
    request = Slack::Api::CheckedChatPostMessage.new(
      token: "xoxb-synthetic-derived",
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

    request.result.status_code.should eq 200
  end

  ["result", "call"].each do |method|
    ["1710000000.000001", "1710000000.000000", "999999999.123456", "10000000000.123456", "1710000000.1", "1710000000.123456789"].each do |timestamp|
      it "preserves timestamp #{timestamp} and broadcasts through #{method}" do
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
        request = Slack::Api::CheckedChatPostMessage.new(
          token: "xoxb-synthetic-thread",
          channel: "C-THREAD",
          message: checked_message("Thread"),
          thread_ts: timestamp,
          reply_broadcast: true
        )

        request.validate.should be_empty
        method == "result" ? request.result.status_code.should(eq 200) : request.call.ok?.should(be_true)
        requests.should eq 1
      end
    end

    [nil, false].each do |broadcast|
      it "omits an absent timestamp with reply_broadcast #{broadcast.inspect} through #{method}" do
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
        request = Slack::Api::CheckedChatPostMessage.new(
          token: "xoxb-synthetic-thread",
          channel: "C-THREAD",
          message: checked_message("Thread"),
          reply_broadcast: broadcast
        )

        method == "result" ? request.result.status_code.should(eq 200) : request.call.ok?.should(be_true)
        requests.should eq 1
      end
    end

    ["", " ", "not-a-timestamp", "1710000000", "1710000000.", ".000001",
     "-1710000000.000001", "+1710000000.000001", "1.71e9", "1710000000..000001",
     " 1710000000.000001", "1710000000.000001\n", "１７１０００００００.000001"].each do |timestamp|
      it "rejects malformed timestamp #{timestamp.inspect} before HTTP through #{method}" do
        requests = 0
        WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |_request|
          requests += 1
          HTTP::Client::Response.new(500)
        end

        [nil, false, true].each do |broadcast|
          request = Slack::Api::CheckedChatPostMessage.new(
            token: "xoxb-synthetic-thread",
            channel: "C-THREAD",
            message: checked_message("Thread"),
            thread_ts: timestamp,
            reply_broadcast: broadcast
          )

          request.validate.map { |issue| {issue.code, issue.path} }.should eq [
            {"chat_post_message.thread_ts.invalid", "thread_ts"},
          ]
          error = expect_raises(Slack::UI::Checked::ValidationError) do
            method == "result" ? request.result : request.call
          end
          error.issues.map { |issue| {issue.code, issue.path} }.should eq [
            {"chat_post_message.thread_ts.invalid", "thread_ts"},
          ]
          requests.should eq 0
        end
      end
    end

    it "rejects an empty channel before HTTP through #{method}" do
      requests = 0
      WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |_request|
        requests += 1
        HTTP::Client::Response.new(500)
      end
      request = Slack::Api::CheckedChatPostMessage.new(
        token: "xoxb-synthetic-invalid",
        channel: "",
        message: checked_message("Invalid")
      )

      error = expect_raises(Slack::UI::Checked::ValidationError) do
        method == "result" ? request.result : request.call
      end
      error.issues.map(&.code).should contain("chat_post_message.channel.empty")
      requests.should eq 0
    end

    it "requires a thread when reply_broadcast is true through #{method}" do
      requests = 0
      WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |_request|
        requests += 1
        HTTP::Client::Response.new(500)
      end
      request = Slack::Api::CheckedChatPostMessage.new(
        token: "xoxb-synthetic-thread",
        channel: "C-THREAD",
        message: checked_message("Thread"),
        reply_broadcast: true
      )

      error = expect_raises(Slack::UI::Checked::ValidationError) do
        method == "result" ? request.result : request.call
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"chat_post_message.reply_broadcast.thread_required", "reply_broadcast"},
      ]
      requests.should eq 0
    end
  end

  it "owns a message snapshot separately from caller collections" do
    section = Slack::UI::Checked::Blocks::Section.new(
      text: Slack::UI::Checked.plain("Before")
    )
    blocks = [section]
    message = Slack::UI::Checked::Message.new(
      fallback_text: "Snapshot",
      blocks: blocks
    )
    request = Slack::Api::CheckedChatPostMessage.new(
      token: "xoxb-synthetic-snapshot",
      channel: "C-SNAPSHOT",
      message: message
    )
    before = request.to_json

    blocks.clear
    message.blocks.clear

    request.to_json.should eq before
  end

  it "preserves Slack API response errors" do
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .to_return(body: %({"ok":false,"error":"invalid_blocks"}))

    expect_raises(Slack::Errors::Api) do
      Slack::Api::CheckedChatPostMessage.new(
        token: "xoxb-synthetic-error",
        channel: "C-ERROR",
        message: checked_message("Error")
      ).call
    end
  end
end

private def checked_message(text : String) : Slack::UI::Checked::Message
  Slack::UI::Checked::Message.new(
    fallback_text: "#{text} fallback",
    blocks: [Slack::UI::Checked::Blocks::Section.new(
      text: Slack::UI::Checked.plain(text)
    )]
  )
end
