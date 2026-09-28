require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Triages an incident message: acknowledges it with a reaction, pins it, adds
# the runbook to the channel bookmarks, and then reads the reactions and pins.
module OfflineIncidentTriageExample
  CHANNEL    = "C123"
  INCIDENT   = "1710000000.000100"
  RUNBOOK    = "https://runbooks.example.test/queue"
  REACT_BODY = %({"channel":"C123","name":"eyes","timestamp":"1710000000.000100"})

  # Returns the form of each pin and bookmark request that the example sent, in order.
  def self.run(output : IO = STDOUT) : Array(URI::Params)
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxb-synthetic-triage", transport: OfflineExample::WebMockTransport.new)
    sent = stub_writes
    stub_reads

    begin
      client.call(Slack::Api::ReactionsAdd.new(channel: CHANNEL, name: "eyes", timestamp: INCIDENT))
    rescue error : Slack::Api::Error
      raise error unless error.code == "already_reacted"
      output.puts "Already watching"
    end
    client.call(Slack::Api::PinsAdd.new(CHANNEL, INCIDENT))
    bookmark = client.call(Slack::Api::BookmarksAdd.new(CHANNEL, "Queue runbook", RUNBOOK, emoji: ":books:")).bookmark
    output.puts "Bookmarked #{bookmark.title} (#{bookmark.id})"

    item = client.call(Slack::Api::ReactionsGet.new(channel: CHANNEL, timestamp: INCIDENT))
    reactions = item.message.try(&.reactions) || [] of Slack::Models::Reaction
    output.puts "Reactions: #{reactions.join(", ") { |reaction| "#{reaction.name} x#{reaction.count}" }}"
    pins = client.call(Slack::Api::PinsList.new(CHANNEL)).items
    output.puts "Pinned: #{pins.join(", ") { |pin| pin.message.try(&.text) }}"
    sent
  end

  # Another responder already added :eyes:, so Slack answers already_reacted.
  private def self.stub_writes : Array(URI::Params)
    WebMock.stub(:post, "https://slack.com/api/reactions.add")
      .with(body: REACT_BODY)
      .to_return(body: %({"ok":false,"error":"already_reacted"}))
    sent = [] of URI::Params
    {"pins.add"      => %({"ok":true}),
     "bookmarks.add" => <<-JSON,
       {"ok":true,"bookmark":{"id":"Bk01","channel_id":"C123","title":"Queue runbook",
        "link":"https://runbooks.example.test/queue","emoji":":books:","type":"link",
        "date_created":1710000060,"date_updated":0,"rank":"g"}}
       JSON
    }.each do |method, response|
      WebMock.stub(:post, "https://slack.com/api/#{method}").to_return do |request|
        sent << URI::Params.parse(request.body.to_s)
        HTTP::Client::Response.new(200, body: response)
      end
    end
    sent
  end

  private def self.stub_reads : Nil
    WebMock.stub(:post, "https://slack.com/api/reactions.get")
      .with(body: "channel=C123&timestamp=1710000000.000100")
      .to_return(body: <<-JSON)
        {"ok":true,"type":"message","channel":"C123",
         "message":{"type":"message","text":"Queue is stuck","user":"U1","ts":"1710000000.000100",
          "reactions":[{"name":"eyes","users":["U2"],"count":1},{"name":"rotating_light","users":["U1","U3"],"count":2}]}}
        JSON
    WebMock.stub(:post, "https://slack.com/api/pins.list")
      .with(body: "channel=C123")
      .to_return(body: <<-JSON)
        {"ok":true,"items":[{"type":"message","channel":"C123","created":1710000030,"created_by":"U4",
         "message":{"type":"message","text":"Queue is stuck","user":"U1","ts":"1710000000.000100"}}]}
        JSON
  end
end
