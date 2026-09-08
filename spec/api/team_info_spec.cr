require "../spec_helper"

describe Slack::Api::TeamInfo do
  describe "#call" do
    it "should request the team info resource from the API" do
      WebMock.stub(:get, "https://slack.com/api/team.info")
        .with(headers: {"Authorization" => "Bearer #{ENV.fetch("SLACK_TEAM_AUTH_TOKEN")}"})
        .to_return(body: File.read("spec/fixtures/api/team-info-success.json"))

      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
      response = Slack::Api::TeamInfo
        .new(token: token)
        .call
        .should be_a(Slack::Models::Team)
      response.name.should eq "goalsurfer"
    end
  end
end
