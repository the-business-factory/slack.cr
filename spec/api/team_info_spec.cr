require "../spec_helper"

describe Slack::Api::TeamInfo do
  describe "#call" do
    it "should request the team info resource from the API" do
      load_cassette("team-info-success") do
        token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN", "faketoken")
        response = Slack::Api::TeamInfo.new(token: token).call
        response.is_a?(Slack::Api::Team).should be_true
        response.name.should eq "goalsurfer"
      end
    end
  end
end
