require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ChatUnfurl do
  it "unfurls links in a posted message with blocks and an attachment" do
    unfurls = {
      "https://example.com/issues/7" => Slack::UI::Unfurl.new(
        blocks: [Slack::UI::Blocks::Section.new(text: Slack::UI.mrkdwn("*Issue 7*: Login fails"))],
        preview: Slack::UI::Unfurl::Preview.new(title: "Issue 7", icon_url: "https://example.com/icon.png")),
    }
    request = Slack::Api::ChatUnfurl.new(channel: "C123ABC456", ts: "1710000000.000300", unfurls: unfurls)
    unfurls.clear
    expected = JSON.parse(<<-JSON)
      {"channel":"C123ABC456","ts":"1710000000.000300","unfurls":{
        "https://example.com/issues/7":{
          "blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*Issue 7*: Login fails"}}],
          "preview":{"title":{"type":"plain_text","text":"Issue 7"},"icon_url":"https://example.com/icon.png"}}}}
      JSON
    WebMock.stub(:post, "https://slack.com/api/chat.unfurl")
      .with(headers: {"Content-Type" => "application/json; charset=utf-8"})
      .to_return do |http_request|
        JSON.parse(http_request.body || fail("Expected JSON body")).should eq expected
        HTTP::Client::Response.new(200, body: %({"ok":true}))
      end

    ApiSupport.client.call(request).ok?.should be_true
    request.unfurls.should_not(be_nil).keys.should eq ["https://example.com/issues/7"]
  end

  it "unfurls a composer link by ID with an attachment and asks the user to authenticate" do
    unfurls = {"https://example.com/doc" => Slack::UI::Attachment.new(text: "Design doc", fallback: "Design doc")}
    request = Slack::Api::ChatUnfurl.new(
      unfurl_id: "gryl3kb80b3wm49ihzoo35fyqoq08n2y", source: Slack::Api::ChatUnfurl::Source::Composer,
      unfurls: unfurls, user_auth_required: true, user_auth_message: "Connect your account to see previews.",
      user_auth_url: "https://example.com/connect",
      user_auth_blocks: [Slack::UI::Blocks::Section.new(text: Slack::UI.plain("Connect your account"))])

    JSON.parse(request.to_json).should eq JSON.parse(<<-JSON)
      {"unfurl_id":"gryl3kb80b3wm49ihzoo35fyqoq08n2y","source":"composer",
       "unfurls":{"https://example.com/doc":{"fallback":"Design doc","text":"Design doc"}},
       "user_auth_required":true,"user_auth_message":"Connect your account to see previews.",
       "user_auth_url":"https://example.com/connect",
       "user_auth_blocks":[{"type":"section","text":{"type":"plain_text","text":"Connect your account"}}]}
      JSON
  end

  it "sends conversations_history as the source for a posted message link" do
    request = Slack::Api::ChatUnfurl.new(unfurl_id: "U1",
      source: Slack::Api::ChatUnfurl::Source::ConversationsHistory, user_auth_required: true)

    JSON.parse(request.to_json).should eq JSON.parse(
      %({"unfurl_id":"U1","source":"conversations_history","user_auth_required":true}))
  end

  it "rejects blank identifiers and URL keys before transport" do
    unfurl = Slack::UI::Unfurl.new(blocks: [Slack::UI::Blocks::Divider.new])
    {
      {Slack::Api::ChatUnfurl.new(channel: " ", ts: "1.1", unfurls: {"https://a.example" => unfurl}),
       "chat_unfurl.channel.blank", "channel"},
      {Slack::Api::ChatUnfurl.new(channel: "C1", ts: "1", unfurls: {"https://a.example" => unfurl}),
       "chat_unfurl.ts.invalid", "ts"},
      {Slack::Api::ChatUnfurl.new(unfurl_id: "", source: Slack::Api::ChatUnfurl::Source::Composer,
        unfurls: {"https://a.example" => unfurl}), "chat_unfurl.unfurl_id.blank", "unfurl_id"},
      {Slack::Api::ChatUnfurl.new(channel: "C1", ts: "1.1", unfurls: {" " => unfurl}),
       "chat_unfurl.unfurls.url_blank", "unfurls"},
    }.each do |request, code, path|
      expect_raises(Slack::UI::ValidationError) { ApiSupport.client.call(request) }
        .issues.map { |issue| {issue.code, issue.path} }.should eq [{code, path}]
    end
  end

  it "raises cannot_unfurl_url as the error code" do
    WebMock.stub(:post, "https://slack.com/api/chat.unfurl")
      .to_return(body: %({"ok":false,"error":"cannot_unfurl_url"}))
    request = Slack::Api::ChatUnfurl.new(channel: "C1", ts: "1.1",
      unfurls: {"https://a.example" => Slack::UI::Unfurl.new(blocks: [Slack::UI::Blocks::Divider.new])})

    expect_raises(Slack::Api::Error) { ApiSupport.client.call(request) }.code.should eq "cannot_unfurl_url"
  end
end

describe Slack::UI::Unfurl do
  it "requires blocks and a nonblank preview title" do
    expect_raises(Slack::UI::ValidationError) { Slack::UI::Unfurl.new(blocks: [] of Slack::UI::MessageBlock) }
      .issues.map(&.code).should eq ["message.blocks.empty"]
    expect_raises(Slack::UI::ValidationError) { Slack::UI::Unfurl::Preview.new(title: " ") }
      .issues.map { |issue| {issue.code, issue.path} }.should eq [{"unfurl.preview.title.blank", "title"}]
  end
end
