require "../spec_helper"

CHANNEL_CONVERSATION_ID = "C032TLM43GA"
IM_CONVERSATION_ID      = "D03ATRRQDMH"

describe Slack::Api::ConversationsInfo do
  context "IM conversations" do
    describe "#call" do
      it "should request the conversation info resource from the API" do
        load_cassette("conversations-info-#{IM_CONVERSATION_ID}") do
          token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
          response = Slack::Api::ConversationsInfo
            .new(token: token, channel: IM_CONVERSATION_ID)
            .call
            .should be_a(Slack::Models::IMChat)

          response.latest.user.should eq(response.user)
        end
      end
    end
  end

  context "Channels" do
    describe "#call" do
      it "should request the conversation info resource from the API" do
        load_cassette("conversations-info-#{CHANNEL_CONVERSATION_ID}") do
          token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
          response = Slack::Api::ConversationsInfo
            .new(token: token, channel: CHANNEL_CONVERSATION_ID)
            .call
            .should be_a(Slack::Models::PublicChannel)

          response.name.should eq "links"
        end
      end
    end
  end

  context "MPIM channels" do
  end
end
