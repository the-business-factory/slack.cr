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

    latest = im.latest.should_not be_nil
    latest.user.should eq im.user
  end

  it "reads a channel as a public channel" do
    stub_conversation("C032TLM43GA")

    channel = ApiSupport.client.call(Slack::Api::ConversationsInfo.new("C032TLM43GA"))
      .should be_a(Slack::Models::PublicChannel)

    channel.name.should eq "links"
  end

  it "reads a private channel from the channel object" do
    WebMock.stub(:post, "https://slack.com/api/conversations.info")
      .to_return(body: %({"ok":true,"channel":{"id":"G1","name":"design","is_group":true,"created":1449252889}}))

    channel = ApiSupport.client.call(Slack::Api::ConversationsInfo.new("G1")).should be_a(Slack::Models::PrivateChannel)

    channel.created.should eq Time.unix(1449252889)
  end

  it "sends the locale and member count options and reads both fields" do
    WebMock.stub(:post, "https://slack.com/api/conversations.info")
      .with(body: "channel=C1&include_locale=true&include_num_members=true")
      .to_return(body: <<-JSON)
        {"ok":true,"channel":{"id":"C1","name":"general","is_channel":true,"is_private":false,
        "created":1449252889,"creator":"U1","name_normalized":"general","previous_names":[],
        "topic":{"value":""},"purpose":{"value":""},"locale":"en-US","num_members":23}}
        JSON

    request = Slack::Api::ConversationsInfo.new("C1", include_locale: true, include_num_members: true)
    channel = ApiSupport.client.call(request)

    channel.locale.should eq "en-US"
    channel.num_members.should eq 23
  end

  it "reports a response without a channel object as invalid" do
    WebMock.stub(:post, "https://slack.com/api/conversations.info").to_return(body: %({"ok":true}))

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ConversationsInfo.new("C1"))
    end.code.should eq "invalid_response"
  end
end
