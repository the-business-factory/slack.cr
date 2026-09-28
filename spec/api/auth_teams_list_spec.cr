require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::AuthTeamsList do
  it "reads every workspace across two cursor pages" do
    requests = [] of URI::Params
    first_page = <<-JSON
      {"ok":true,"teams":[{"name":"Shinichi's workspace","id":"T12345678",
       "icon":{"image_34":"https://icons.example.test/34.png","image_default":false}}],
       "response_metadata":{"next_cursor":"dXNlcl9pZDo5MTQyOTI5Mzkz"}}
      JSON
    pages = [first_page,
             %({"ok":true,"teams":[{"name":"Migi's workspace","id":"T12345679"}],"response_metadata":{"next_cursor":""}})]
    WebMock.stub(:post, "https://slack.com/api/auth.teams.list").to_return do |request|
      requests << URI::Params.parse(request.body.to_s)
      HTTP::Client::Response.new(200, body: pages[requests.size - 1])
    end

    teams = [] of Slack::Models::Auth::Team
    ApiSupport.client.each_page(Slack::Api::AuthTeamsList.new(include_icon: true, limit: 1)) do |page|
      teams.concat(page.model.teams)
    end

    teams.map(&.id).should eq %w[T12345678 T12345679]
    teams.map(&.name).should eq ["Shinichi's workspace", "Migi's workspace"]
    teams[0].icon.try(&.["image_34"]).should eq "https://icons.example.test/34.png"
    teams[1].icon.should be_nil
    requests.should eq [
      URI::Params.parse("include_icon=true&limit=1"),
      URI::Params.parse("include_icon=true&cursor=dXNlcl9pZDo5MTQyOTI5Mzkz&limit=1"),
    ]
  end
end
