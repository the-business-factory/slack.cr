require "../spec_helper"
require "../support/auth/webmock_transport"

CHANNEL_CONVERSATION_ID = "C032TLM43GA"
IM_CONVERSATION_ID      = "D03ATRRQDMH"

describe Slack::Api::ConversationsInfo do
  context "IM conversations" do
    describe "#call" do
      it "should request the conversation info resource from the API" do
        WebMock.stub(:get, "https://slack.com/api/conversations.info?channel=#{IM_CONVERSATION_ID}")
          .with(headers: {"Authorization" => "Bearer #{ENV.fetch("SLACK_TEAM_AUTH_TOKEN")}"})
          .to_return(body: File.read("spec/fixtures/api/conversations-info-#{IM_CONVERSATION_ID}.json"))

        token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
        response = Slack::Api::ConversationsInfo
          .new(token: token, channel: IM_CONVERSATION_ID, transport: AuthSupport::WebMockTransport.new)
          .call
          .should be_a(Slack::Models::IMChat)

        response.latest.user.should eq(response.user)
      end
    end
  end

  context "Channels" do
    describe "#call" do
      it "should request the conversation info resource from the API" do
        WebMock.stub(:get, "https://slack.com/api/conversations.info?channel=#{CHANNEL_CONVERSATION_ID}")
          .with(headers: {"Authorization" => "Bearer #{ENV.fetch("SLACK_TEAM_AUTH_TOKEN")}"})
          .to_return(body: File.read("spec/fixtures/api/conversations-info-#{CHANNEL_CONVERSATION_ID}.json"))

        token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
        response = Slack::Api::ConversationsInfo
          .new(token: token, channel: CHANNEL_CONVERSATION_ID, transport: AuthSupport::WebMockTransport.new)
          .call
          .should be_a(Slack::Models::PublicChannel)

        response.name.should eq "links"
      end
    end
  end

  context "MPIM channels" do
  end
end
