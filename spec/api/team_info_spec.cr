require "../spec_helper"
require "../support/api/webmock_client"

private def stub_team_info(form : String, response : String) : Nil
  WebMock.stub(:post, "https://slack.com/api/team.info")
    .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                    "Content-Type"  => "application/x-www-form-urlencoded"})
    .to_return do |request|
      request.body.to_s.should eq form
      HTTP::Client::Response.new(200, body: response)
    end
end

describe Slack::Api::TeamInfo do
  it "posts an empty form and reads the current workspace" do
    stub_team_info("", File.read("spec/fixtures/api/team-info-success.json"))

    team = ApiSupport.client.call(Slack::Api::TeamInfo.new)

    team.id.should eq "T017GL5AV5E"
    team.name.should eq "goalsurfer"
    team.domain.should eq "goalsurfer"
    team.is_verified.should be_false
  end

  it "reads another workspace by ID with its organization fields" do
    stub_team_info("team=T12345", <<-JSON)
      {"ok":true,"team":{"id":"T12345","name":"My Team","domain":"example","email_domain":"example.com",
       "icon":{"image_34":"https://icons.example.test/34.png","image_default":true},
       "enterprise_id":"E1234A12AB","enterprise_name":"Umbrella Corporation"}}
      JSON

    team = ApiSupport.client.call(Slack::Api::TeamInfo.new(team: "T12345"))

    team.email_domain.should eq "example.com"
    team.enterprise_id.should eq "E1234A12AB"
    team.enterprise_name.should eq "Umbrella Corporation"
    team.url.should be_nil
  end

  it "reads a workspace by domain" do
    stub_team_info("domain=example", %({"ok":true,"team":{"id":"T12345","name":"My Team"}}))

    ApiSupport.client.call(Slack::Api::TeamInfo.new(domain: "example")).id.should eq "T12345"
  end
end
