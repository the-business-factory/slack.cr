require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ChatGetPermalink do
  it "sends the channel and message timestamp as form fields and reads the permalink" do
    WebMock.stub(:post, "https://slack.com/api/chat.getPermalink")
      .with(body: "channel=C123ABC456&message_ts=1358546515.000008",
        headers: {"Content-Type" => "application/x-www-form-urlencoded"})
      .to_return(body: <<-JSON)
        {"ok":true,"channel":"C123ABC456",
         "permalink":"https://ghostbusters.slack.com/archives/C1H9RESGA/p135854651500008"}
        JSON

    response = ApiSupport.client.call(
      Slack::Api::ChatGetPermalink.new(channel: "C123ABC456", message_ts: "1358546515.000008"))

    response.channel.should eq "C123ABC456"
    response.permalink.should eq "https://ghostbusters.slack.com/archives/C1H9RESGA/p135854651500008"
  end

  it "rejects a malformed timestamp and raises message_not_found from Slack" do
    Slack::Api::ChatGetPermalink.new(channel: "", message_ts: "135854651").validate
      .map { |issue| {issue.code, issue.path} }
      .should eq [{"chat_get_permalink.channel.blank", "channel"}, {"chat_get_permalink.message_ts.invalid", "message_ts"}]
    WebMock.stub(:post, "https://slack.com/api/chat.getPermalink")
      .to_return(body: %({"ok":false,"error":"message_not_found"}))

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ChatGetPermalink.new(channel: "C1", message_ts: "1.1"))
    end.code.should eq "message_not_found"
  end
end
