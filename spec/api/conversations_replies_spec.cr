require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ConversationsReplies do
  it "sends the thread and window as form fields and reads the replies" do
    WebMock.stub(:post, "https://slack.com/api/conversations.replies")
      .with(headers: {"Content-Type" => "application/x-www-form-urlencoded"})
      .to_return do |request|
        URI::Params.parse(request.body.to_s).should eq URI::Params.parse(
          "channel=C123ABC456&ts=1482960137.003543&include_all_metadata=true&inclusive=true" \
          "&latest=1482960200.000000&limit=15&oldest=1482960137.003543")
        HTTP::Client::Response.new(200, body: <<-JSON)
          {"ok": true, "has_more": true,
           "messages": [
             {"type": "message", "user": "U061F7AUR", "text": "island", "thread_ts": "1482960137.003543",
              "reply_count": 1, "subscribed": true, "last_read": "1484678597.521003", "unread_count": 0,
              "ts": "1482960137.003543"},
             {"type": "message", "user": "U061F7AUR", "text": "one island", "thread_ts": "1482960137.003543",
              "parent_user_id": "U061F7AUR", "ts": "1483037603.017503"}],
           "response_metadata": {"next_cursor": "bmV4dF90czoxNDg0Njc4MjkwNTE3MDkx"}}
          JSON
      end

    request = Slack::Api::ConversationsReplies.new("C123ABC456", "1482960137.003543",
      include_all_metadata: true, inclusive: true, latest: "1482960200.000000", oldest: "1482960137.003543",
      limit: 15)
    replies = ApiSupport.client.call(request)

    replies.has_more.should be_true
    replies.messages.map(&.text).should eq ["island", "one island"]
    replies.messages[0].reply_count.should eq 1
  end

  it "omits unset window fields so Slack applies its defaults" do
    WebMock.stub(:post, "https://slack.com/api/conversations.replies")
      .with(body: "channel=C1&ts=1.2")
      .to_return(body: %({"ok":true,"has_more":false,"messages":[]}))

    ApiSupport.client.call(Slack::Api::ConversationsReplies.new("C1", "1.2")).messages.should be_empty
  end
end
