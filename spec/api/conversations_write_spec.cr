require "../spec_helper"
require "../support/api/webmock_client"

# Stubs *method* and checks that the request body is the expected JSON object.
private def stub_json(method : String, expected : String, response : String = %({"ok":true})) : Nil
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                    "Content-Type"  => "application/json; charset=utf-8"})
    .to_return do |request|
      JSON.parse(request.body || fail("Expected a JSON request body")).should eq JSON.parse(expected)
      HTTP::Client::Response.new(200, body: response)
    end
end

private def stub_error(method : String, code : String) : Nil
  WebMock.stub(:post, "https://slack.com/api/#{method}").to_return(body: %({"ok":false,"error":"#{code}"}))
end

private def issue_codes(request : Slack::Api::Request) : Array(String)
  request.validate.map(&.code)
end

# The documented conversations.create example, trimmed of unmodeled fields.
private ENDEAVOR = <<-JSON
  {"ok":true,"channel":{"id":"C0EAQDV4Z","name":"endeavor","is_channel":true,"is_group":false,
   "is_im":false,"created":1504554479,"creator":"U0123456","is_archived":false,"is_general":false,
   "unlinked":0,"name_normalized":"endeavor","is_shared":false,"is_ext_shared":false,
   "is_org_shared":false,"pending_shared":[],"is_pending_ext_shared":false,"is_member":true,
   "is_private":false,"is_mpim":false,"last_read":"0000000000.000000","latest":null,"unread_count":0,
   "unread_count_display":0,"topic":{"value":"","creator":"","last_set":0},
   "purpose":{"value":"","creator":"","last_set":0},"previous_names":[],"priority":0}}
  JSON

describe Slack::Api::ConversationsOpen do
  it "opens a group direct message with a comma-separated user list" do
    stub_json("conversations.open", %({"users":"U1,U2","prevent_creation":true}),
      %({"ok":true,"no_op":true,"already_open":true,"channel":{"id":"G069C7QFK"}}))

    response = ApiSupport.client.call(Slack::Api::ConversationsOpen.new(users: %w[U1 U2], prevent_creation: true))

    response.channel_id.should eq "G069C7QFK"
    response.channel.should be_a(Slack::Models::Conversations::ConversationRef)
    response.no_op?.should be_true
    response.already_open?.should be_true
  end

  it "resumes a direct message and reads the full IM definition" do
    stub_json("conversations.open", %({"channel":"D069C7QFK","return_im":true}), <<-JSON)
      {"ok":true,"no_op":true,"already_open":true,"channel":{"id":"D069C7QFK","created":1460147748,
       "is_im":true,"is_org_shared":false,"user":"U069C7QF3","last_read":"0000000000.000000",
       "latest":null,"unread_count":0,"unread_count_display":0,"is_open":true,"priority":0}}
      JSON

    response = ApiSupport.client.call(Slack::Api::ConversationsOpen.new(channel: "D069C7QFK", return_im: true))

    im = response.channel.should be_a(Slack::Models::IMChat)
    im.user.should eq "U069C7QF3"
    im.created.should eq Time.unix(1460147748)
    response.channel_id.should eq "D069C7QFK"
  end

  it "reads the full group direct message definition" do
    stub_json("conversations.open", %({"users":"U1,U2","return_im":true}), <<-JSON)
      {"ok":true,"channel":{"id":"G024BE91L","name":"mpdm-user1--user2--user3-1","is_mpim":true,
       "is_group":false,"is_im":false,"is_private":true,"created":1360782804,"creator":"U024BE7LH",
       "members":["U024BE7LH","U1","U2"],"latest":null}}
      JSON

    response = ApiSupport.client.call(Slack::Api::ConversationsOpen.new(users: %w[U1 U2], return_im: true))

    group = response.channel.should be_a(Slack::Models::PrivateChannel)
    group.is_mpim?.should be_true
    group.name.should eq "mpdm-user1--user2--user3-1"
    response.channel_id.should eq "G024BE91L"
  end

  it "reads a response without no_op or already_open as a new conversation" do
    stub_json("conversations.open", %({"users":"U1"}), %({"ok":true,"channel":{"id":"D1"}}))

    response = ApiSupport.client.call(Slack::Api::ConversationsOpen.new(users: ["U1"]))

    response.no_op?.should be_false
    response.already_open?.should be_false
  end

  it "accepts one to eight users" do
    issue_codes(Slack::Api::ConversationsOpen.new(users: [] of String)).should eq ["conversations_open.users.empty"]
    issue_codes(Slack::Api::ConversationsOpen.new(users: (1..8).map { |i| "U#{i}" })).should be_empty
    issue_codes(Slack::Api::ConversationsOpen.new(users: (1..9).map { |i| "U#{i}" }))
      .should eq ["conversations_open.users.too_many"]
  end

  it "copies the user list once" do
    users = ["U1"]
    request = Slack::Api::ConversationsOpen.new(users: users)
    users << "U2"

    request.users.should eq ["U1"]
    JSON.parse(request.body).should eq JSON.parse(%({"users":"U1"}))
  end
end

describe Slack::Api::ConversationsCreate do
  it "creates a private channel for a workspace and reads it" do
    stub_json("conversations.create", %({"name":"endeavor","is_private":true,"team_id":"T1"}), ENDEAVOR)

    channel = ApiSupport.client.call(Slack::Api::ConversationsCreate.new("endeavor", is_private: true, team_id: "T1"))

    channel = channel.should be_a(Slack::Models::PublicChannel)
    channel.id.should eq "C0EAQDV4Z"
    channel.is_member?.should be_true
  end

  it "sends only the name for a public channel" do
    stub_json("conversations.create", %({"name":"endeavor"}), ENDEAVOR)

    ApiSupport.client.call(Slack::Api::ConversationsCreate.new("endeavor")).id.should eq "C0EAQDV4Z"
  end

  it "raises name_taken as an API error" do
    stub_error("conversations.create", "name_taken")

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ConversationsCreate.new("endeavor"))
    end.code.should eq "name_taken"
  end

  it "rejects a blank name and a name longer than 80 characters" do
    issue_codes(Slack::Api::ConversationsCreate.new(" ")).should eq ["conversations_create.name.blank"]
    issue_codes(Slack::Api::ConversationsCreate.new("a" * 80)).should be_empty
    issue_codes(Slack::Api::ConversationsCreate.new("a" * 81)).should eq ["conversations_create.name.too_long"]
  end
end

describe Slack::Api::ConversationsRename do
  it "renames a conversation and reads the renamed channel" do
    stub_json("conversations.rename", %({"channel":"C012AB3CD","name":"general"}), <<-JSON)
      {"ok":true,"channel":{"id":"C012AB3CD","name":"general","is_channel":true,"is_group":false,
       "is_im":false,"created":1449252889,"creator":"W012A3BCD","is_archived":false,"is_general":true,
       "name_normalized":"general","is_private":false,"is_mpim":false,"is_member":true,
       "topic":{"value":"For public discussion of generalities","creator":"W012A3BCD","last_set":1449709364},
       "purpose":{"value":"This part of the workspace is for fun.","creator":"W012A3BCD","last_set":1449709364},
       "previous_names":["specifics","abstractions","etc"],"num_members":23,"locale":"en-US"}}
      JSON

    channel = ApiSupport.client.call(Slack::Api::ConversationsRename.new("C012AB3CD", "general"))
      .should be_a(Slack::Models::PublicChannel)

    channel.previous_names.should eq %w[specifics abstractions etc]
    channel.num_members.should eq 23
  end

  it "applies the channel name rules of conversations.create" do
    issue_codes(Slack::Api::ConversationsRename.new("C1", "")).should eq ["conversations_rename.name.blank"]
    issue_codes(Slack::Api::ConversationsRename.new("C1", "a" * 81)).should eq ["conversations_rename.name.too_long"]
  end
end

describe Slack::Api::ConversationsJoin do
  it "joins a channel and reads it when Slack warns that the app is already a member" do
    stub_json("conversations.join", %({"channel":"C061EG9SL"}), <<-JSON)
      {"ok":true,"channel":{"id":"C061EG9SL","name":"general","is_channel":true,"is_group":false,
       "is_im":false,"created":1449252889,"creator":"U061F7AUR","is_archived":false,"is_general":true,
       "name_normalized":"general","is_member":true,"is_private":false,"is_mpim":false,
       "topic":{"value":"Which widget do you worry about?","creator":"","last_set":0},
       "purpose":{"value":"For widget discussion","creator":"","last_set":0},"previous_names":[]},
       "warning":"already_in_channel","response_metadata":{"warnings":["already_in_channel"]}}
      JSON

    channel = ApiSupport.client.call(Slack::Api::ConversationsJoin.new("C061EG9SL"))
      .should be_a(Slack::Models::PublicChannel)

    channel.name.should eq "general"
    channel.is_general?.should be_true
  end
end

describe Slack::Api::ConversationsInvite do
  it "invites users as a comma-separated list and reads the channel" do
    stub_json("conversations.invite", %({"channel":"C0EAQDV4Z","users":"U1,U2","force":true}), ENDEAVOR)

    request = Slack::Api::ConversationsInvite.new("C0EAQDV4Z", %w[U1 U2], force: true)
    ApiSupport.client.call(request).id.should eq "C0EAQDV4Z"
  end

  it "raises the first error of a partial failure" do
    WebMock.stub(:post, "https://slack.com/api/conversations.invite").to_return(body: <<-JSON)
      {"ok":false,"error":"user_not_found","errors":[{"user":"U111111","ok":false,"error":"user_not_found"},
       {"user":"U222222","ok":false,"error":"cant_invite_self"}]}
      JSON

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ConversationsInvite.new("C1", %w[U111111 U222222]))
    end.code.should eq "user_not_found"
  end

  it "accepts one to 1000 users" do
    issue_codes(Slack::Api::ConversationsInvite.new("C1", [] of String)).should eq ["conversations_invite.users.empty"]
    issue_codes(Slack::Api::ConversationsInvite.new("C1", (1..1000).map { |i| "U#{i}" })).should be_empty
    issue_codes(Slack::Api::ConversationsInvite.new("C1", (1..1001).map { |i| "U#{i}" }))
      .should eq ["conversations_invite.users.too_many"]
  end

  it "copies the user list once" do
    users = ["U1"]
    request = Slack::Api::ConversationsInvite.new("C1", users)
    users << "U2"

    request.users.should eq ["U1"]
  end
end

describe Slack::Api::ConversationsKick do
  it "removes one user from a conversation" do
    stub_json("conversations.kick", %({"channel":"C1","user":"U1"}), %({"ok":true,"errors":{}}))

    ApiSupport.client.call(Slack::Api::ConversationsKick.new("C1", "U1")).ok?.should be_true
  end

  it "raises not_in_channel as an API error" do
    stub_error("conversations.kick", "not_in_channel")

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ConversationsKick.new("C1", "U1"))
    end.code.should eq "not_in_channel"
  end
end

describe Slack::Api::ConversationsLeave do
  it "leaves a conversation" do
    stub_json("conversations.leave", %({"channel":"C1"}))

    ApiSupport.client.call(Slack::Api::ConversationsLeave.new("C1")).not_in_channel?.should be_false
  end

  it "reads the not_in_channel flag of a successful response" do
    stub_json("conversations.leave", %({"channel":"C1"}), %({"ok":true,"not_in_channel":true}))

    ApiSupport.client.call(Slack::Api::ConversationsLeave.new("C1")).not_in_channel?.should be_true
  end

  it "raises the documented unsuccessful not_in_channel form, which has no error name" do
    WebMock.stub(:post, "https://slack.com/api/conversations.leave").to_return(body: %({"ok":false,"not_in_channel":true}))

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ConversationsLeave.new("C1"))
    end.code.should eq "unknown_error"
  end
end

describe "conversation state requests" do
  it "sends the channel and value of each request as JSON" do
    stub_json("conversations.archive", %({"channel":"C1"}))
    stub_json("conversations.unarchive", %({"channel":"C1"}))
    stub_json("conversations.setPurpose", %({"channel":"C1","purpose":"Deploy coordination"}))
    stub_json("conversations.mark", %({"channel":"C1","ts":"1593473566.000200"}))

    client = ApiSupport.client
    client.call(Slack::Api::ConversationsArchive.new("C1")).ok?.should be_true
    client.call(Slack::Api::ConversationsUnarchive.new("C1")).ok?.should be_true
    client.call(Slack::Api::ConversationsSetPurpose.new("C1", "Deploy coordination")).ok?.should be_true
    client.call(Slack::Api::ConversationsMark.new("C1", "1593473566.000200")).ok?.should be_true
  end

  it "raises channel_not_found as an API error" do
    stub_error("conversations.archive", "channel_not_found")

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ConversationsArchive.new("C404"))
    end.code.should eq "channel_not_found"
  end

  it "sets a topic and reads the channel with the new topic" do
    stub_json("conversations.setTopic", %({"channel":"C12345678","topic":"Apply topically for best effects"}), <<-JSON)
      {"ok":true,"channel":{"id":"C12345678","name":"tips-and-tricks","is_channel":true,"is_group":false,
       "is_im":false,"is_mpim":false,"is_private":false,"created":1649195947,"is_archived":false,
       "is_general":false,"name_normalized":"tips-and-tricks","creator":"U12345678","is_member":true,
       "last_read":"1649869848.627809","unread_count":1,"unread_count_display":0,
       "topic":{"value":"Apply topically for best effects","creator":"U12345678","last_set":1649952691},
       "purpose":{"value":"","creator":"","last_set":0},"previous_names":[]}}
      JSON

    request = Slack::Api::ConversationsSetTopic.new("C12345678", "Apply topically for best effects")
    channel = ApiSupport.client.call(request).should be_a(Slack::Models::PublicChannel)

    channel.topic["value"].should eq "Apply topically for best effects"
  end

  it "accepts an empty topic or purpose and rejects more than 250 characters" do
    issue_codes(Slack::Api::ConversationsSetTopic.new("C1", "")).should be_empty
    issue_codes(Slack::Api::ConversationsSetTopic.new("C1", "é" * 250)).should be_empty
    issue_codes(Slack::Api::ConversationsSetTopic.new("C1", "a" * 251)).should eq ["conversations_set_topic.topic.too_long"]
    issue_codes(Slack::Api::ConversationsSetPurpose.new("C1", "a" * 251))
      .should eq ["conversations_set_purpose.purpose.too_long"]
  end

  it "rejects a mark timestamp without a fraction" do
    issue_codes(Slack::Api::ConversationsMark.new("C1", "1593473566"))
      .should eq ["conversations_mark.ts.invalid"]
  end
end
