require "../spec_helper"
require "../support/api/webmock_client"

private def stub_conversation(channel : String) : Nil
  WebMock.stub(:post, "https://slack.com/api/conversations.info")
    .with(body: "channel=#{channel}", headers: {"Authorization" => "Bearer xoxb-synthetic",
                                                "Content-Type"  => "application/x-www-form-urlencoded"})
    .to_return(body: File.read("spec/fixtures/api/conversations-info-#{channel}.json"))
end

describe Slack::Api::ConversationsInfo do
  it "reads a direct message conversation as an IM" do
    stub_conversation("D03ATRRQDMH")

    im = ApiSupport.client.call(Slack::Api::ConversationsInfo.new("D03ATRRQDMH")).should be_a(Slack::Models::IMChat)

    im.latest.user.should eq im.user
  end

  it "reads a channel as a public channel" do
    stub_conversation("C032TLM43GA")

    channel = ApiSupport.client.call(Slack::Api::ConversationsInfo.new("C032TLM43GA"))
      .should be_a(Slack::Models::PublicChannel)

    channel.name.should eq "links"
  end

  it "reads a private channel from the channel object" do
    WebMock.stub(:post, "https://slack.com/api/conversations.info")
      .to_return(body: %({"ok":true,"channel":{"id":"G1","is_group":true,"created":1449252889}}))

    channel = ApiSupport.client.call(Slack::Api::ConversationsInfo.new("G1")).should be_a(Slack::Models::PrivateChannel)

    channel.created.should eq Time.unix(1449252889)
  end

  it "reports a response without a channel object as invalid" do
    WebMock.stub(:post, "https://slack.com/api/conversations.info").to_return(body: %({"ok":true}))

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ConversationsInfo.new("C1"))
    end.code.should eq "invalid_response"
  end
end
