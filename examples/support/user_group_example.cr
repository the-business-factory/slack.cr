require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Reads the workspace members page by page, finds the team lead by email,
# and puts the active people into a new on-call user group.
module OfflineUserGroupExample
  LEAD_EMAIL = "ana@example.test"

  # Returns the form of each user group request that the example sent, in order.
  def self.run(output : IO = STDOUT) : Array(URI::Params)
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-user-group",
      transport: OfflineExample::WebMockTransport.new)
    stub_users
    sent = stub_usergroups

    people = [] of Slack::Models::User
    client.each_page(Slack::Api::UsersList.new(limit: 2)) do |page|
      people.concat(page.model.members.reject { |user| user.deleted? || user.is_bot? })
    end
    output.puts "People: #{people.join(", ", &.profile.display_name)}"

    lead = client.call(Slack::Api::UsersLookupByEmail.new(LEAD_EMAIL)).user
    output.puts "Lead: #{lead.real_name} (#{lead.tz})"

    group = client.call(Slack::Api::UsergroupsCreate.new("On-call", handle: "oncall",
      description: "Led by #{lead.real_name}")).usergroup
    group = client.call(Slack::Api::UsergroupsUsersUpdate.new(group.id, people.map(&.id),
      include_count: true)).usergroup
    output.puts "@#{group.handle}: #{group.user_count} members"
    sent
  end

  # Slack sends the second page when the request carries the first page's next_cursor.
  private def self.stub_users : Nil
    WebMock.stub(:post, "https://slack.com/api/users.list")
      .with(body: "limit=2")
      .to_return(body: <<-JSON)
        {"ok":true,"members":[
        {"id":"U1","team_id":"T1","name":"ana","real_name":"Ana Ruiz","tz":"Europe/Madrid",
         "profile":{"display_name":"ana","email":"ana@example.test"}},
        {"id":"B1","team_id":"T1","name":"deploybot","is_bot":true,"profile":{"display_name":"deploybot"}}],
        "response_metadata":{"next_cursor":"dXNlcjpCMQ=="}}
        JSON
    WebMock.stub(:post, "https://slack.com/api/users.list")
      .with(body: "cursor=dXNlcjpCMQ%3D%3D&limit=2")
      .to_return(body: <<-JSON)
        {"ok":true,"members":[
        {"id":"U2","team_id":"T1","name":"ben","deleted":true,"profile":{"display_name":"ben"}},
        {"id":"U3","team_id":"T1","name":"cy","profile":{"display_name":"cy"}}],
        "response_metadata":{"next_cursor":""}}
        JSON
    WebMock.stub(:post, "https://slack.com/api/users.lookupByEmail")
      .with(body: "email=ana%40example.test")
      .to_return(body: <<-JSON)
        {"ok":true,"user":{"id":"U1","team_id":"T1","name":"ana","real_name":"Ana Ruiz",
         "tz":"Europe/Madrid","profile":{"display_name":"ana","email":"ana@example.test"}}}
        JSON
  end

  private def self.stub_usergroups : Array(URI::Params)
    sent = [] of URI::Params
    {"usergroups.create" => %("users":[]), "usergroups.users.update" => %("users":["U1","U3"],"user_count":2)}
      .each do |method, members|
        WebMock.stub(:post, "https://slack.com/api/#{method}").to_return do |request|
          sent << URI::Params.parse(request.body.to_s)
          HTTP::Client::Response.new(200, body: <<-JSON)
            {"ok":true,"usergroup":{"id":"S1","team_id":"T1","name":"On-call","handle":"oncall",
             "date_create":1789232400,"date_update":1789232400,"date_delete":0,#{members}}}
            JSON
        end
      end
    sent
  end
end
