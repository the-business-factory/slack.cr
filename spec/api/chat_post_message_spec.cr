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

describe "Slack::Api::ChatPostMessage content and message options" do
  it "posts blocks with attachments, metadata, an emoji icon, and every message option" do
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected a JSON request body")).should eq JSON.parse(<<-JSON)
        {
          "channel": "C0DEPLOY1",
          "text": "Deploy 812 finished",
          "blocks": [
            {"type": "section", "block_id": "deploy.summary", "text": {"type": "mrkdwn", "text": "*Deploy 812* finished"}}
          ],
          "attachments": [
            {
              "color": "#2EB886",
              "fallback": "api: healthy",
              "pretext": "Service checks",
              "author_name": "deploybot",
              "author_link": "https://example.com/deploys",
              "author_icon": "https://example.com/bot.png",
              "title": "Deploy 812",
              "title_link": "https://example.com/deploys/812",
              "text": "api: *healthy*",
              "fields": [
                {"title": "Region", "value": "us-east-1", "short": true},
                {"title": "Duration", "value": "4m"}
              ],
              "image_url": "https://example.com/graph.png",
              "footer": "Deploy pipeline",
              "footer_icon": "https://example.com/footer.png",
              "ts": 1710000123,
              "mrkdwn_in": ["text"]
            },
            {
              "color": "good",
              "blocks": [{"type": "context", "elements": [{"type": "mrkdwn", "text": "Rolled out to 3 regions"}]}],
              "thumb_url": "https://example.com/thumb.png"
            }
          ],
          "thread_ts": "1710000000.000100",
          "reply_broadcast": true,
          "metadata": {"event_type": "deploy_finished", "event_payload": {"deploy_id": "812", "healthy": true}},
          "mrkdwn": true,
          "parse": "none",
          "link_names": false,
          "unfurl_links": false,
          "unfurl_media": false,
          "unfurl_app_links": true,
          "username": "deploybot",
          "icon_emoji": ":rocket:",
          "as_user": false
        }
        JSON
      HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-post-success-attachment.json"))
    end

    message = Slack::UI::Message.new(fallback_text: "Deploy 812 finished", blocks: [
      Slack::UI::Blocks::Section.new(text: Slack::UI.mrkdwn("*Deploy 812* finished"), block_id: "deploy.summary"),
    ])
    request = Slack::Api::ChatPostMessage.new(
      channel: "C0DEPLOY1",
      message: message,
      attachments: [detailed_attachment, block_attachment],
      thread_ts: "1710000000.000100",
      reply_broadcast: true,
      metadata: Slack::UI::MessageMetadata.new(
        event_type: "deploy_finished",
        event_payload: {"deploy_id" => JSON::Any.new("812"), "healthy" => JSON::Any.new(true)}
      ),
      mrkdwn: true,
      parse: Slack::Api::ChatPostMessage::Parse::None,
      link_names: false,
      unfurl_links: false,
      unfurl_media: false,
      unfurl_app_links: true,
      username: "deploybot",
      icon: Slack::UI::Icon::Emoji.new(":rocket:"),
      as_user: false
    )

    ApiSupport.client.call(request).ts.should eq "1710000123.000200"
  end

  it "posts markdown_text without text or blocks" do
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected a JSON request body")).should eq JSON.parse(<<-'JSON')
        {"channel": "C0DEPLOY1", "markdown_text": "**Deploy 812** finished\n\n- api: healthy", "icon_url": "https://example.com/bot.png"}
        JSON
      HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-post-success-attachment.json"))
    end

    request = Slack::Api::ChatPostMessage.new(
      channel: "C0DEPLOY1",
      markdown_text: "**Deploy 812** finished\n\n- api: healthy",
      icon: Slack::UI::Icon::Url.new("https://example.com/bot.png")
    )
    ApiSupport.client.call(request).ok?.should be_true
  end

  it "posts plain text with full parsing and an attachment" do
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |http_request|
      JSON.parse(http_request.body || fail("Expected a JSON request body")).should eq JSON.parse(<<-JSON)
        {"channel": "C0DEPLOY1", "text": "Deploy 812 finished for @oncall", "parse": "full",
         "attachments": [{"color": "danger", "text": "web: unhealthy"}]}
        JSON
      HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-post-success-attachment.json"))
    end

    request = Slack::Api::ChatPostMessage.new(
      channel: "C0DEPLOY1",
      text: "Deploy 812 finished for @oncall",
      parse: Slack::Api::ChatPostMessage::Parse::Full,
      attachments: [Slack::UI::Attachment.new(color: Slack::UI::Attachment::Color.danger, text: "web: unhealthy")]
    )
    ApiSupport.client.call(request).ok?.should be_true
  end

  it "reads the posted message with typed common fields" do
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .to_return(body: File.read("spec/fixtures/api/chat-post-success-attachment.json"))

    response = ApiSupport.client.call(Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1", text: "Deploy 812 finished"))

    response.channel.should eq "C0DEPLOY1"
    posted = response.message
    posted.ts.should eq "1710000123.000200"
    posted.type.should eq "message"
    posted.subtype.should eq "bot_message"
    posted.text.should eq "Deploy 812 finished"
    posted.user.should be_nil
    posted.bot_id.should eq "B0DEPLOY1"
    posted.thread_ts.should eq "1710000000.000100"
    section = posted.blocks.first.should be_a(Slack::Interactions::ReceivedBlocks::Section)
    section.block_id.should eq "deploy.summary"
    attachments = posted.attachments.should_not be_nil
    attachments[0]["color"].as_s.should eq "2eb886"
    metadata = posted.metadata.should_not be_nil
    metadata["event_payload"]["deploy_id"].as_s.should eq "812"
  end

  it "rejects more than 100 attachments before HTTP" do
    attachments = Array.new(101) { Slack::UI::Attachment.new(fallback: "item") }

    request = Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1", text: "Many", attachments: attachments)

    request.validate.map { |issue| {issue.code, issue.path} }.should eq [
      {"chat_post_message.attachments.too_many", "attachments"},
    ]
    expect_raises(Slack::UI::ValidationError) { ApiSupport.client.call(request) }
  end

  it "rejects empty text and oversized markdown_text before HTTP" do
    Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1", text: "").validate.map(&.code)
      .should eq ["chat_post_message.text.empty"]
    Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1", markdown_text: "").validate.map(&.code)
      .should eq ["chat_post_message.markdown_text.empty"]
    Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1", markdown_text: "a" * 12_000).validate.should be_empty
    Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1", markdown_text: "a" * 12_001).validate.map(&.code)
      .should eq ["chat_post_message.markdown_text.too_long"]
  end

  it "rejects a blank username" do
    request = Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1", text: "Hi", username: " ")

    request.validate.map { |issue| {issue.code, issue.path} }.should eq [
      {"chat_post_message.username.blank", "username"},
    ]
  end

  it "limits Markdown block text across the message and its attachments" do
    request = Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1",
      message: Slack::UI::Message.new(fallback_text: "Summary", blocks: [Slack::UI::Blocks::Markdown.new("a" * 6_000)]),
      attachments: [markdown_attachment(4_000), markdown_attachment(2_000)])
    request.validate.should be_empty

    request = Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1",
      message: Slack::UI::Message.new(fallback_text: "Summary", blocks: [Slack::UI::Blocks::Markdown.new("a" * 6_000)]),
      attachments: [markdown_attachment(4_000), markdown_attachment(2_001)])
    request.validate.map { |issue| {issue.code, issue.path} }.should eq [
      {"chat_post_message.markdown.too_long", "attachments"},
    ]
    expect_raises(Slack::UI::ValidationError) { request.to_json }
  end

  it "rejects block IDs repeated across the message and its attachments" do
    section = Slack::UI::Blocks::Section.new(text: Slack::UI.plain("Review"), block_id: "review")
    child = Slack::UI::Blocks::Section.new(text: Slack::UI.plain("Child"), block_id: "child")
    container = Slack::UI::Blocks::Container.new(title: Slack::UI.plain("Group"), child_blocks: [child], block_id: "group")
    request = Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1",
      message: Slack::UI::Message.new(fallback_text: "Review", blocks: [section, container]),
      attachments: [
        Slack::UI::Attachment.new(blocks: [Slack::UI::Blocks::Divider.new(block_id: "other")]),
        Slack::UI::Attachment.new(blocks: [Slack::UI::Blocks::Divider.new(block_id: "review"), Slack::UI::Blocks::Divider.new(block_id: "child")]),
        Slack::UI::Attachment.new(blocks: [Slack::UI::Blocks::Divider.new(block_id: "other")]),
      ])

    request.validate.map { |issue| {issue.code, issue.path} }.should eq [
      {"chat_post_message.block_id.duplicate", "attachments[1].blocks[0].block_id"},
      {"chat_post_message.block_id.duplicate", "attachments[1].blocks[1].block_id"},
      {"chat_post_message.block_id.duplicate", "attachments[2].blocks[0].block_id"},
    ]

    distinct = Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1",
      message: Slack::UI::Message.new(fallback_text: "Review", blocks: [section]),
      attachments: [Slack::UI::Attachment.new(blocks: [Slack::UI::Blocks::Divider.new(block_id: "other")])])
    distinct.validate.should be_empty
  end

  it "owns copies of attachments and metadata payloads" do
    attachments = [Slack::UI::Attachment.new(fallback: "first")]
    payload = {"deploy_id" => JSON::Any.new("812")}
    request = Slack::Api::ChatPostMessage.new(channel: "C0DEPLOY1", text: "Hi", attachments: attachments,
      metadata: Slack::UI::MessageMetadata.new(event_type: "deploy_finished", event_payload: payload))
    before = request.to_json

    attachments << Slack::UI::Attachment.new(fallback: "second")
    payload["deploy_id"] = JSON::Any.new("999")
    request.attachments.should_not be_nil
    request.metadata.try(&.event_payload.as_h.clear)

    request.to_json.should eq before
  end
end

describe Slack::UI::Attachment do
  it "requires fallback or text when it has no blocks" do
    error = expect_raises(Slack::UI::ValidationError) { Slack::UI::Attachment.new(color: Slack::UI::Attachment::Color.good) }
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"attachment.fallback.required", "fallback"},
    ]
    Slack::UI::Attachment.new(text: "Only text").validate.should be_empty
  end

  it "requires author_name for author links and icons, and footer for footer icons" do
    error = expect_raises(Slack::UI::ValidationError) do
      Slack::UI::Attachment.new(fallback: "x", author_link: "https://example.com", author_icon: "https://example.com/a.png",
        footer_icon: "https://example.com/f.png")
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"attachment.author_link.author_name_required", "author_link"},
      {"attachment.author_icon.author_name_required", "author_icon"},
      {"attachment.footer_icon.footer_required", "footer_icon"},
    ]
  end

  it "rejects image_url together with thumb_url" do
    error = expect_raises(Slack::UI::ValidationError) do
      Slack::UI::Attachment.new(fallback: "x", image_url: "https://example.com/graph.png", thumb_url: "https://example.com/thumb.png")
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"attachment.image_url.thumb_url_conflict", "image_url"},
    ]
  end

  it "limits the footer to 300 characters" do
    Slack::UI::Attachment.new(fallback: "x", footer: "f" * 300).validate.should be_empty
    error = expect_raises(Slack::UI::ValidationError) { Slack::UI::Attachment.new(fallback: "x", footer: "f" * 301) }
    error.issues.map(&.code).should eq ["attachment.footer.too_long"]
  end

  it "validates attachment blocks with the message block rules" do
    section = Slack::UI::Blocks::Section.new(text: Slack::UI.plain("One"), block_id: "same")
    error = expect_raises(Slack::UI::ValidationError) { Slack::UI::Attachment.new(blocks: [section, section]) }
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"message.block_id.duplicate", "blocks[1].block_id"},
    ]
  end

  it "accepts only #RRGGBB hex colors" do
    Slack::UI::Attachment::Color.hex("#2eb886").wire_value.should eq "#2eb886"
    ["2eb886", "#2eb88", "#2eb8866", "#gggggg", "", "#2EB886\n"].each do |value|
      error = expect_raises(Slack::UI::ValidationError) { Slack::UI::Attachment::Color.hex(value) }
      error.issues.map(&.code).should eq ["attachment.color.invalid_hex"]
    end
  end

  it "keeps a copy of its blocks and fields" do
    blocks = [Slack::UI::Blocks::Divider.new] of Slack::UI::MessageBlock
    fields = [Slack::UI::Attachment::Field.new(title: "Region", value: "us-east-1")]
    attachment = Slack::UI::Attachment.new(blocks: blocks, fields: fields, fallback: "x")
    before = attachment.to_json

    blocks.clear
    fields.clear
    attachment.blocks.try(&.clear)
    attachment.fields.try(&.clear)

    attachment.to_json.should eq before
  end
end

describe Slack::UI::MessageMetadata do
  it "rejects a blank event type and a non-object payload" do
    error = expect_raises(Slack::UI::ValidationError) do
      Slack::UI::MessageMetadata.new(event_type: " ", event_payload: JSON::Any.new([JSON::Any.new(1_i64)]))
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"message_metadata.event_type.blank", "event_type"},
      {"message_metadata.event_payload.not_object", "event_payload"},
    ]
  end
end

describe Slack::UI::Icon do
  it "rejects blank emoji and URL icons" do
    expect_raises(Slack::UI::ValidationError) { Slack::UI::Icon::Emoji.new("") }
      .issues.map(&.code).should eq ["icon.emoji.blank"]
    expect_raises(Slack::UI::ValidationError) { Slack::UI::Icon::Url.new(" ") }
      .issues.map(&.code).should eq ["icon.url.blank"]
  end
end

private def detailed_attachment : Slack::UI::Attachment
  Slack::UI::Attachment.new(
    color: Slack::UI::Attachment::Color.hex("#2EB886"),
    fallback: "api: healthy",
    pretext: "Service checks",
    author_name: "deploybot",
    author_link: "https://example.com/deploys",
    author_icon: "https://example.com/bot.png",
    title: "Deploy 812",
    title_link: "https://example.com/deploys/812",
    text: "api: *healthy*",
    fields: [
      Slack::UI::Attachment::Field.new(title: "Region", value: "us-east-1", short: true),
      Slack::UI::Attachment::Field.new(title: "Duration", value: "4m"),
    ],
    image_url: "https://example.com/graph.png",
    footer: "Deploy pipeline",
    footer_icon: "https://example.com/footer.png",
    ts: 1710000123_i64,
    mrkdwn_in: ["text"]
  )
end

private def markdown_attachment(size : Int32) : Slack::UI::Attachment
  Slack::UI::Attachment.new(blocks: [Slack::UI::Blocks::Markdown.new("a" * size)])
end

private def block_attachment : Slack::UI::Attachment
  Slack::UI::Attachment.new(
    color: Slack::UI::Attachment::Color.good,
    blocks: [Slack::UI::Blocks::Context.new(elements: [Slack::UI.mrkdwn("Rolled out to 3 regions")])],
    thumb_url: "https://example.com/thumb.png"
  )
end
