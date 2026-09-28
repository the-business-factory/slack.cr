require "../spec_helper"
require "../support/api/webmock_client"

private def stub_form(method : String, form : String, response : String) : Nil
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                    "Content-Type"  => "application/x-www-form-urlencoded"})
    .to_return do |request|
      URI::Params.parse(request.body.to_s).should eq URI::Params.parse(form)
      HTTP::Client::Response.new(200, body: response)
    end
end

# The documented usergroups.create example, with users and an unknown field added.
private MARKETING = <<-JSON
  {"ok":true,"usergroup":{"id":"S0615G0KT","team_id":"T060RNRCH","is_usergroup":true,
   "name":"Marketing Team","description":"Marketing gurus, PR experts and product advocates.",
   "handle":"marketing-team","is_external":false,"date_create":1446746793,"date_update":1446746793,
   "date_delete":0,"auto_type":null,"created_by":"U060RNRCZ","updated_by":"U060RNRCZ","deleted_by":null,
   "prefs":{"channels":["C1"],"groups":[]},"users":["U060R4BJ4","W123A4BC5"],"user_count":"2",
   "channel_count":1}}
  JSON

describe Slack::Api::UsergroupsCreate do
  it "sends the group fields and reads the created group" do
    stub_form("usergroups.create",
      "name=Marketing+Team&channels=C1%2CC2&additional_channels=C3&description=Marketing+gurus" \
      "&handle=marketing-team&include_count=true&team_id=T060RNRCH&enable_section=true", MARKETING)

    request = Slack::Api::UsergroupsCreate.new("Marketing Team", channels: %w[C1 C2],
      additional_channels: %w[C3], description: "Marketing gurus", handle: "marketing-team",
      include_count: true, team_id: "T060RNRCH", enable_section: true)
    group = ApiSupport.client.call(request).usergroup

    group.id.should eq "S0615G0KT"
    group.handle.should eq "marketing-team"
    group.description.should eq "Marketing gurus, PR experts and product advocates."
    group.users.should eq %w[U060R4BJ4 W123A4BC5]
    group.user_count.should eq 2
    group.channels.should eq ["C1"]
    group.date_delete.should eq 0
    group.enabled?.should be_true
    group.deleted_by.should be_nil
  end

  it "rejects a blank name, empty channel lists, and a section without default channels" do
    Slack::Api::UsergroupsCreate.new(" ").validate.map(&.code).should eq ["usergroups.name.blank"]
    Slack::Api::UsergroupsCreate.new("Ops", channels: [] of String, additional_channels: [] of String)
      .validate.map(&.code).should eq ["usergroups.channels.empty", "usergroups.additional_channels.empty"]
    Slack::Api::UsergroupsCreate.new("Ops", enable_section: true)
      .validate.map(&.code).should eq ["usergroups.enable_section.channels_missing"]
  end

  it "copies the channel lists once" do
    channels = ["C1"]
    request = Slack::Api::UsergroupsCreate.new("Ops", channels: channels)
    channels << "C2"

    request.form.to_s.should eq "name=Ops&channels=C1"
  end
end

describe Slack::Api::UsergroupsUpdate do
  it "sends only the changed fields" do
    stub_form("usergroups.update", "usergroup=S0615G0KT&name=Marketing&handle=mktg", MARKETING)

    request = Slack::Api::UsergroupsUpdate.new("S0615G0KT", name: "Marketing", handle: "mktg")
    ApiSupport.client.call(request).usergroup.name.should eq "Marketing Team"
  end

  it "sends enable_section only when supplied, including false" do
    Slack::Api::UsergroupsUpdate.new("S1", enable_section: false).body.should eq "usergroup=S1&enable_section=false"
    Slack::Api::UsergroupsUpdate.new("S1", enable_section: true).body.should eq "usergroup=S1&enable_section=true"
    Slack::Api::UsergroupsUpdate.new("S1").body.should eq "usergroup=S1"
  end

  it "reads a numeric user_count" do
    stub_form("usergroups.update", "usergroup=S1&include_count=true", <<-JSON)
      {"ok":true,"usergroup":{"id":"S1","team_id":"T1","name":"Ops","handle":"ops","date_create":1,
       "date_update":2,"date_delete":0,"user_count":3}}
      JSON

    ApiSupport.client.call(Slack::Api::UsergroupsUpdate.new("S1", include_count: true))
      .usergroup.user_count.should eq 3
  end
end

describe Slack::Models::Usergroup do
  it "serializes a decoded group with its user count and reads it back" do
    group = Slack::Models::Usergroup.from_json(
      %({"id":"S1","team_id":"T1","name":"Ops","handle":"ops","date_create":1,"date_update":2,"user_count":"3"}))

    JSON.parse(group.to_json)["user_count"].should eq 3
    Slack::Models::Usergroup.from_json(group.to_json).user_count.should eq 3
  end
end

describe Slack::Api::UsergroupsList do
  it "sends the options and reads every group" do
    stub_form("usergroups.list", "include_count=true&include_disabled=true&include_users=true&team_id=T1", <<-JSON)
      {"ok":true,"usergroups":[
        {"id":"S0614TZR7","team_id":"T060RNRCH","is_usergroup":true,"name":"Team Admins",
         "description":"A group of all Administrators on your team.","handle":"admins","is_external":false,
         "date_create":1446598059,"date_update":1446670362,"date_delete":0,"auto_type":"admin",
         "created_by":"USLACKBOT","updated_by":"U060RNRCZ","deleted_by":null,
         "prefs":{"channels":[],"groups":[]},"users":["U060RNRCZ"],"user_count":"1"},
        {"id":"S2","team_id":"T060RNRCH","name":"Old","handle":"old","date_create":1,"date_update":2,
         "date_delete":1446670400,"deleted_by":"U060RNRCZ"}]}
      JSON

    request = Slack::Api::UsergroupsList.new(include_count: true, include_disabled: true,
      include_users: true, team_id: "T1")
    groups = ApiSupport.client.call(request).usergroups

    groups.map(&.handle).should eq %w[admins old]
    groups[0].auto_type.should eq "admin"
    groups.map(&.enabled?).should eq [true, false]
    groups[1].users.should be_nil
    groups[1].channels.should be_empty
  end
end

describe Slack::Api::UsergroupsUsersList do
  it "reads the member IDs" do
    stub_form("usergroups.users.list", "usergroup=S0604QSJC&include_disabled=true",
      %({"ok":true,"users":["U060R4BJ4","W123A4BC5"]}))

    request = Slack::Api::UsergroupsUsersList.new("S0604QSJC", include_disabled: true)
    ApiSupport.client.call(request).users.should eq %w[U060R4BJ4 W123A4BC5]
  end
end

describe Slack::Api::UsergroupsUsersUpdate do
  it "sends the full member list and reads the group" do
    stub_form("usergroups.users.update",
      "usergroup=S0615G0KT&users=U060R4BJ4%2CW123A4BC5&include_count=true&additional_channels=C3&is_shared=true",
      MARKETING)

    request = Slack::Api::UsergroupsUsersUpdate.new("S0615G0KT", %w[U060R4BJ4 W123A4BC5],
      include_count: true, additional_channels: %w[C3], is_shared: true)
    ApiSupport.client.call(request).usergroup.users.should eq %w[U060R4BJ4 W123A4BC5]
  end

  it "rejects an empty member list before sending" do
    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(Slack::Api::UsergroupsUsersUpdate.new("S1", [] of String))
    end
    error.issues.map(&.code).should eq ["usergroups_users_update.users.empty"]
  end
end

describe Slack::Api::UsergroupsDisable do
  it "reads the disabled group when Slack returns it" do
    stub_form("usergroups.disable", "usergroup=S1&include_count=true&team_id=T1", <<-JSON)
      {"ok":true,"usergroup":{"id":"S1","team_id":"T1","name":"Ops","handle":"ops","date_create":1,
       "date_update":2,"date_delete":1446670400,"user_count":0}}
      JSON

    request = Slack::Api::UsergroupsDisable.new("S1", include_count: true, team_id: "T1")
    group = ApiSupport.client.call(request).usergroup.should_not be_nil
    group.enabled?.should be_false
  end
end

describe Slack::Api::UsergroupsEnable do
  it "accepts a response without a group" do
    stub_form("usergroups.enable", "usergroup=S1", %({"ok":true}))

    ApiSupport.client.call(Slack::Api::UsergroupsEnable.new("S1")).usergroup.should be_nil
  end
end
