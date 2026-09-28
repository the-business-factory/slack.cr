require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::TeamInfo do
  it "posts an empty form and reads the team object" do
    WebMock.stub(:post, "https://slack.com/api/team.info")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                      "Content-Type"  => "application/x-www-form-urlencoded"})
      .to_return do |request|
        request.body.to_s.should be_empty
        HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/team-info-success.json"))
      end

    ApiSupport.client.call(Slack::Api::TeamInfo.new).name.should eq "goalsurfer"
  end
end
