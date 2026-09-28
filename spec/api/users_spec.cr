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

private def stub_json(method : String, expected : String, response : String = %({"ok":true})) : Nil
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Content-Type" => "application/json; charset=utf-8"})
    .to_return do |request|
      JSON.parse(request.body.to_s).should eq JSON.parse(expected)
      HTTP::Client::Response.new(200, body: response)
    end
end

describe Slack::Api::UsersInfo do
  it "reads a user and its profile and ignores unknown fields" do
    stub_form("users.info", "user=W012A3CDE&include_locale=true",
      File.read("spec/fixtures/api/users-info-success.json"))

    user = ApiSupport.client.call(Slack::Api::UsersInfo.new("W012A3CDE", include_locale: true)).user

    user.id.should eq "W012A3CDE"
    user.team_id.should eq "T012AB3C4"
    user.name.should eq "spengler"
    user.real_name.should eq "Egon Spengler"
    user.tz.should eq "America/Los_Angeles"
    user.locale.should eq "en-US"
    user.is_admin?.should be_true
    user.is_owner?.should be_false
    user.is_bot?.should be_false
    user.deleted?.should be_false
    user.profile.display_name.should eq "spengler"
    user.profile.email.should eq "spengler@ghostbusters.example.com"
    user.profile.status_emoji.should eq ":books:"
    user.profile.status_expiration.should eq 0
    user.profile.image_72.should eq "https://avatars.example.test/spengler_72.jpg"
  end

  it "reads a bot user whose optional fields are missing" do
    stub_form("users.info", "user=U0BOT", <<-JSON)
      {"ok":true,"user":{"id":"U0BOT","name":"deploybot","deleted":false,"is_bot":true,
       "profile":{"bot_id":"B0BOT","real_name":"Deploy Bot"}}}
      JSON

    user = ApiSupport.client.call(Slack::Api::UsersInfo.new("U0BOT")).user

    user.is_bot?.should be_true
    user.is_admin?.should be_false
    user.team_id.should be_nil
    user.profile.bot_id.should eq "B0BOT"
    user.profile.email.should be_nil
  end

  it "raises the Slack error code for an unknown user" do
    stub_form("users.info", "user=U404", %({"ok":false,"error":"user_not_found"}))

    error = expect_raises(Slack::Api::Error) { ApiSupport.client.call(Slack::Api::UsersInfo.new("U404")) }
    error.code.should eq "user_not_found"
  end
end

describe Slack::Api::UsersList do
  it "reads every member across two cursor pages" do
    requests = [] of URI::Params
    first_page = <<-JSON
      {"ok":true,"cache_ts":1498777272,"members":[
        {"id":"U1","team_id":"T1","name":"ana","deleted":false,"is_admin":true,"profile":{"real_name":"Ana"}},
        {"id":"U2","team_id":"T1","name":"ben","deleted":true,"profile":{"real_name":"Ben"}}],
        "response_metadata":{"next_cursor":"dXNlcjpVMg=="}}
      JSON
    last_page = <<-JSON
      {"ok":true,"members":[
        {"id":"U3","team_id":"T1","name":"cy","deleted":false,"is_owner":true,"profile":{"real_name":"Cy"}}],
        "response_metadata":{"next_cursor":""}}
      JSON
    pages = [first_page, last_page]
    WebMock.stub(:post, "https://slack.com/api/users.list").to_return do |request|
      requests << URI::Params.parse(request.body.to_s)
      HTTP::Client::Response.new(200, body: pages[requests.size - 1])
    end

    users = [] of Slack::Models::User
    request = Slack::Api::UsersList.new(include_locale: true, team_id: "T1", limit: 2)
    ApiSupport.client.each_page(request) { |page| users.concat(page.model.members) }

    users.map(&.name).should eq %w[ana ben cy]
    users.map(&.deleted?).should eq [false, true, false]
    users.last.is_owner?.should be_true
    requests.should eq [
      URI::Params.parse("include_locale=true&team_id=T1&limit=2"),
      URI::Params.parse("include_locale=true&team_id=T1&cursor=dXNlcjpVMg%3D%3D&limit=2"),
    ]
  end

  it "sends an empty form by default and rejects a limit above 1000 before sending" do
    stub_form("users.list", "", %({"ok":true,"members":[]}))

    ApiSupport.client.call(Slack::Api::UsersList.new).members.should be_empty
    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(Slack::Api::UsersList.new(limit: 1001))
    end
    error.issues.map(&.code).should eq ["pagination.limit.out_of_range"]
  end
end

describe Slack::Api::UsersLookupByEmail do
  it "sends the email and reads the user" do
    stub_form("users.lookupByEmail", "email=spengler%40ghostbusters.example.com",
      File.read("spec/fixtures/api/users-info-success.json"))

    request = Slack::Api::UsersLookupByEmail.new("spengler@ghostbusters.example.com")
    ApiSupport.client.call(request).user.id.should eq "W012A3CDE"
  end
end

describe Slack::Api::UsersConversations do
  it "sends the user and types and reads conversations by type" do
    form = "user=U1&types=public_channel%2Cim&exclude_archived=true&exclude_muted=true&team_id=T1&limit=50"
    stub_form("users.conversations", form, <<-JSON)
      {"ok":true,"channels":[
        {"id":"C1","name":"general","is_channel":true,"is_group":false,"is_im":false,"created":1449252889,
         "creator":"U2","is_archived":false,"is_general":true,"unlinked":0,"name_normalized":"general",
         "is_shared":false,"is_ext_shared":false,"is_org_shared":false,"pending_shared":[],
         "is_pending_ext_shared":false,"is_private":false,"is_mpim":false,
         "topic":{"value":"Company-wide","creator":"","last_set":0},
         "purpose":{"value":"Announcements","creator":"","last_set":0},"previous_names":[]},
        {"id":"D1","is_im":true,"user":"U2","created":1449252890}],
       "response_metadata":{"next_cursor":""}}
      JSON

    request = Slack::Api::UsersConversations.new(user: "U1",
      types: [Slack::Api::ConversationType::PublicChannel, Slack::Api::ConversationType::Im],
      exclude_archived: true, exclude_muted: true, team_id: "T1", limit: 50)
    channels = ApiSupport.client.call(request).channels

    channels[0].should be_a Slack::Models::PublicChannel
    channels[1].should be_a Slack::Models::IMChat
  end

  it "copies the types once and rejects an empty types list" do
    types = [Slack::Api::ConversationType::PrivateChannel]
    request = Slack::Api::UsersConversations.new(types: types)
    types << Slack::Api::ConversationType::Mpim

    request.form.to_s.should eq "types=private_channel"
    Slack::Api::UsersConversations.new(types: [] of Slack::Api::ConversationType)
      .validate.map(&.code).should eq ["users_conversations.types.empty"]
  end
end

describe Slack::Api::UsersProfileGet do
  it "sends the options and reads the profile" do
    stub_form("users.profile.get", "user=U1&include_labels=true", <<-JSON)
      {"ok":true,"profile":{"title":"Head of Coffee","phone":"","real_name":"Ana Ruiz",
       "display_name":"ana","status_text":"Brewing","status_emoji":":coffee:","status_expiration":1532627506,
       "email":"ana@example.test","first_name":"Ana","last_name":"Ruiz","image_192":"https://avatars.example.test/ana_192.jpg",
       "fields":{"Xf06054AAA":{"value":"Coffee","alt":"","label":"Team"}},"avatar_hash":"ge3b51ca72de"}}
      JSON

    profile = ApiSupport.client.call(Slack::Api::UsersProfileGet.new(user: "U1", include_labels: true)).profile

    profile.title.should eq "Head of Coffee"
    profile.first_name.should eq "Ana"
    profile.status_expiration.should eq 1532627506
    profile.image_192.should eq "https://avatars.example.test/ana_192.jpg"
    fields = profile.fields.should_not be_nil
    fields["Xf06054AAA"]["label"].should eq "Team"
  end
end

describe Slack::Api::UsersProfileSet do
  it "sends a profile object as JSON" do
    expected = <<-JSON
      {"profile":{"status_text":"Watching cold brew steep","status_emoji":":coffee:","status_expiration":0},
       "user":"U1"}
      JSON
    stub_json("users.profile.set", expected,
      %({"ok":true,"profile":{"status_text":"Watching cold brew steep","status_emoji":":coffee:"}}))

    request = Slack::Api::UsersProfileSet.new(
      profile: {status_text: "Watching cold brew steep", status_emoji: ":coffee:", status_expiration: 0},
      user: "U1")
    ApiSupport.client.call(request).profile.status_text.should eq "Watching cold brew steep"
  end

  it "sends one field as name and value" do
    stub_json("users.profile.set", %({"name":"title","value":"Barista"}), %({"ok":true,"profile":{"title":"Barista"}}))

    ApiSupport.client.call(Slack::Api::UsersProfileSet.new(name: "title", value: "Barista"))
      .profile.title.should eq "Barista"
  end

  it "copies the profile and rejects an empty profile or more than 50 fields" do
    fields = {"title" => "Barista"}
    request = Slack::Api::UsersProfileSet.new(profile: fields)
    fields["title"] = "Changed"
    request.body.should eq %({"profile":{"title":"Barista"}})

    Slack::Api::UsersProfileSet.new(profile: {} of String => String)
      .validate.map(&.code).should eq ["users_profile_set.profile.empty"]
    too_many = (1..51).to_h { |index| {"field_#{index}", "value"} }
    Slack::Api::UsersProfileSet.new(profile: too_many)
      .validate.map(&.code).should eq ["users_profile_set.profile.too_many_fields"]
  end
end

describe Slack::Api::UsersGetPresence do
  it "reads the short presence of another user" do
    stub_form("users.getPresence", "user=U2", %({"ok":true,"presence":"away"}))

    presence = ApiSupport.client.call(Slack::Api::UsersGetPresence.new(user: "U2"))

    presence.presence.should eq "away"
    presence.active?.should be_false
    presence.online.should be_nil
  end

  it "reads the connection details of the calling user" do
    stub_form("users.getPresence", "", <<-JSON)
      {"ok":true,"presence":"active","online":true,"auto_away":false,"manual_away":false,
       "connection_count":1,"last_activity":1419027078}
      JSON

    presence = ApiSupport.client.call(Slack::Api::UsersGetPresence.new)

    presence.active?.should be_true
    presence.online.should be_true
    presence.manual_away.should be_false
    presence.connection_count.should eq 1
    presence.last_activity.should eq 1419027078
  end
end

describe Slack::Api::UsersSetPresence do
  it "sends auto or away" do
    stub_form("users.setPresence", "presence=away", %({"ok":true}))
    ApiSupport.client.call(Slack::Api::UsersSetPresence.new(:away)).ok?.should be_true

    WebMock.reset
    stub_form("users.setPresence", "presence=auto", %({"ok":true}))
    ApiSupport.client.call(Slack::Api::UsersSetPresence.new(:auto)).ok?.should be_true
  end
end
