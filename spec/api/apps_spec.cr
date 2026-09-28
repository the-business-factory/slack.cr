require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::AppsUninstall do
  it "sends the app's client ID and secret with the workspace token" do
    sent = [] of URI::Params
    WebMock.stub(:post, "https://slack.com/api/apps.uninstall")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic-workspace",
                      "Content-Type"  => "application/x-www-form-urlencoded"})
      .to_return do |request|
        sent << URI::Params.parse(request.body.to_s)
        HTTP::Client::Response.new(200, body: %({"ok":true}))
      end

    request = Slack::Api::AppsUninstall.new(client_id: "1234.5678", client_secret: "synthetic-client-secret")
    ApiSupport.client("xoxb-synthetic-workspace").call(request).ok?.should be_true

    sent.should eq [URI::Params.parse("client_id=1234.5678&client_secret=synthetic-client-secret")]
  end

  it "keeps the client secret out of inspect output" do
    request = Slack::Api::AppsUninstall.new(client_id: "1234.5678",
      client_secret: Slack::Auth::Secret.new("canary-client-secret"))

    request.inspect.should_not contain("canary")
    request.to_s.should_not contain("canary")
  end

  it "raises the Slack error when the secret does not match the client ID" do
    WebMock.stub(:post, "https://slack.com/api/apps.uninstall")
      .to_return(body: %({"ok":false,"error":"bad_client_secret"}))

    error = expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::AppsUninstall.new(client_id: "1234.5678", client_secret: "wrong"))
    end
    error.code.should eq "bad_client_secret"
  end
end

describe Slack::Api::AppsEventAuthorizationsList do
  it "reads every authorization for an event across cursor pages" do
    requests = [] of URI::Params
    pages = [<<-JSON, <<-JSON]
      {"ok":true,"authorizations":[{"enterprise_id":null,"team_id":"T1","user_id":"U1",
       "is_bot":true,"is_enterprise_install":false}],
       "response_metadata":{"next_cursor":"dGVhbTpUMg=="}}
      JSON
      {"ok":true,"authorizations":[{"enterprise_id":"E1","team_id":null,"user_id":"U2","is_bot":false,
       "is_enterprise_install":true}],"response_metadata":{"next_cursor":""}}
      JSON
    WebMock.stub(:post, "https://slack.com/api/apps.event.authorizations.list")
      .with(headers: {"Authorization" => "Bearer xapp-synthetic-app-level"})
      .to_return do |request|
        requests << URI::Params.parse(request.body.to_s)
        HTTP::Client::Response.new(200, body: pages[requests.size - 1])
      end

    authorizations = [] of Slack::Events::Authorization
    ApiSupport.client("xapp-synthetic-app-level")
      .each_page(Slack::Api::AppsEventAuthorizationsList.new("4-eyJldCI6Im1lc3NhZ2UifQ", limit: 1)) do |page|
        authorizations.concat(page.model.authorizations)
      end

    requests.should eq [
      URI::Params.parse("event_context=4-eyJldCI6Im1lc3NhZ2UifQ&limit=1"),
      URI::Params.parse("event_context=4-eyJldCI6Im1lc3NhZ2UifQ&cursor=dGVhbTpUMg%3D%3D&limit=1"),
    ]
    authorizations.map(&.user_id).should eq ["U1", "U2"]
    authorizations.map(&.bot?).should eq [true, false]
    authorizations.map(&.team_id).should eq ["T1", nil]
    authorizations.map(&.enterprise_id).should eq [nil, "E1"]
    authorizations.map(&.enterprise_install).should eq [false, true]
  end

  it "sends nothing when the limit is out of range" do
    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(Slack::Api::AppsEventAuthorizationsList.new("4-abc", limit: 0))
    end
    error.issues.map(&.code).should eq ["pagination.limit.out_of_range"]
  end
end
