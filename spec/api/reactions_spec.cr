require "../spec_helper"
require "../support/api/webmock_client"

private def stub_form(method : String, form : String, response : String = %({"ok":true})) : Nil
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                    "Content-Type"  => "application/x-www-form-urlencoded"})
    .to_return do |request|
      URI::Params.parse(request.body.to_s).should eq URI::Params.parse(form)
      HTTP::Client::Response.new(200, body: response)
    end
end

describe Slack::Api::ReactionsAdd do
  it "raises already_reacted when the reaction is already on the message" do
    WebMock.stub(:post, "https://slack.com/api/reactions.add")
      .to_return(body: %({"ok":false,"error":"already_reacted"}))

    error = expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ReactionsAdd.new(channel: "C1", name: "eyes", timestamp: "1710000000.000100"))
    end
    error.code.should eq "already_reacted"
  end
end

describe Slack::Api::ReactionsRemove do
  it "removes a reaction from a message" do
    stub_form("reactions.remove", "name=eyes&channel=C1&timestamp=1710000000.000100")

    request = Slack::Api::ReactionsRemove.new("eyes", channel: "C1", timestamp: "1710000000.000100")
    ApiSupport.client.call(request).ok?.should be_true
  end

  it "removes a reaction from a file" do
    stub_form("reactions.remove", "name=thumbsup&file=F1")

    ApiSupport.client.call(Slack::Api::ReactionsRemove.new("thumbsup", file: "F1")).ok?.should be_true
  end

  it "raises no_reaction when the reaction is not on the item" do
    stub_form("reactions.remove", "name=eyes&channel=C1&timestamp=1710000000.000100",
      %({"ok":false,"error":"no_reaction"}))

    error = expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ReactionsRemove.new("eyes", channel: "C1", timestamp: "1710000000.000100"))
    end
    error.code.should eq "no_reaction"
  end

  it "rejects an empty reaction name before sending" do
    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(Slack::Api::ReactionsRemove.new("", file: "F1"))
    end
    error.issues.map(&.code).should eq ["reactions.name.empty"]

    error = expect_raises(Slack::UI::ValidationError) do
      ApiSupport.client.call(Slack::Api::ReactionsAdd.new(channel: "C1", name: "", timestamp: "1710000000.000100"))
    end
    error.issues.map(&.code).should eq ["reactions.name.empty"]
  end
end

describe Slack::Api::ReactionsGet do
  it "reads the reactions of a message" do
    stub_form("reactions.get", "channel=C1&timestamp=1710000000.000100&full=true", <<-JSON)
      {"ok":true,"type":"message","channel":"C1",
       "message":{"type":"message","text":"Deploy done","user":"U1","ts":"1710000000.000100",
        "reactions":[{"name":"tada","users":["U2","U3"],"count":2},{"name":"eyes","users":["U4"],"count":1}],
        "permalink":"https://example.slack.com/archives/C1/p1710000000000100"}}
      JSON

    request = Slack::Api::ReactionsGet.new(channel: "C1", timestamp: "1710000000.000100", full: true)
    item = ApiSupport.client.call(request)

    item.type.should eq "message"
    item.channel.should eq "C1"
    message = item.message.should_not be_nil
    reactions = message.reactions.should_not be_nil
    reactions.map(&.name).should eq %w[tada eyes]
    reactions.first.count.should eq 2
    reactions.first.users.should eq %w[U2 U3]
    item.file.should be_nil
  end

  it "reads the reactions of a file" do
    stub_form("reactions.get", "file=F1", <<-JSON)
      {"ok":true,"type":"file",
       "file":{"id":"F1","name":"report.pdf","reactions":[{"name":"white_check_mark","users":["U1"],"count":1}]}}
      JSON

    item = ApiSupport.client.call(Slack::Api::ReactionsGet.new(file: "F1"))

    item.type.should eq "file"
    item.message.should be_nil
    file = item.file.should_not be_nil
    reactions = file.reactions.should_not be_nil
    reactions.map(&.name).should eq ["white_check_mark"]
  end
end

describe Slack::Api::ReactionsList do
  it "reads the reacted items of a user across two cursor pages" do
    requests = [] of URI::Params
    pages = [<<-JSON, <<-JSON]
      {"ok":true,"items":[
        {"type":"message","channel":"C1",
         "message":{"type":"message","text":"Ship it","ts":"1710000000.000100",
          "reactions":[{"name":"rocket","users":["U1"],"count":1}]}}],
       "response_metadata":{"next_cursor":"aXRlbToy"}}
      JSON
      {"ok":true,"items":[
        {"type":"file","file":{"id":"F1","title":"plan.txt",
          "reactions":[{"name":"eyes","users":["U1"],"count":1}]}}],
       "response_metadata":{"next_cursor":""}}
      JSON
    WebMock.stub(:post, "https://slack.com/api/reactions.list").to_return do |request|
      requests << URI::Params.parse(request.body.to_s)
      HTTP::Client::Response.new(200, body: pages[requests.size - 1])
    end

    items = [] of Slack::Models::Reactions::Item
    request = Slack::Api::ReactionsList.new(user: "U1", full: true, limit: 1)
    ApiSupport.client.each_page(request) { |page| items.concat(page.model.items) }

    items.map(&.type).should eq %w[message file]
    items.first.message.try(&.text).should eq "Ship it"
    items.last.file.try(&.title).should eq "plan.txt"
    requests.should eq [
      URI::Params.parse("user=U1&full=true&limit=1"),
      URI::Params.parse("user=U1&full=true&cursor=aXRlbToy&limit=1"),
    ]
  end

  it "reads a bot message without a nested type and follows the next cursor" do
    pages = [<<-JSON, <<-JSON]
      {"ok":true,"items":[{"type":"message","channel":"C123ABC456",
        "message":{"bot_id":"B123ABC456","reactions":[{"count":1,"name":"robot_face","users":["U123ABC456"]}],
         "subtype":"bot_message","text":"Hello from Python! :tada:","ts":"1507849573.000090",
         "username":"Shipit Notifications"}}],
       "response_metadata":{"next_cursor":"bmV4dA=="}}
      JSON
      {"ok":true,"items":[{"type":"file","file":{"id":"F1","title":"computer.gif"}}],
       "response_metadata":{"next_cursor":""}}
      JSON
    calls = 0
    WebMock.stub(:post, "https://slack.com/api/reactions.list").to_return do
      calls += 1
      HTTP::Client::Response.new(200, body: pages[calls - 1])
    end

    items = [] of Slack::Models::Reactions::Item
    ApiSupport.client.each_page(Slack::Api::ReactionsList.new) { |page| items.concat(page.model.items) }

    message = items.first.message.should_not be_nil
    message.type.should eq "message"
    message.subtype.should eq "bot_message"
    message.bot_id.should eq "B123ABC456"
    message.reactions.try(&.map(&.name)).should eq ["robot_face"]
    items.last.file.try(&.title).should eq "computer.gif"
  end

  it "sends an empty form by default" do
    stub_form("reactions.list", "", %({"ok":true,"items":[]}))

    ApiSupport.client.call(Slack::Api::ReactionsList.new).items.should be_empty
  end
end
