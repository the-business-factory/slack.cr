require "../../src/slack"
require "../../src/slack/testing"

# Sets up an incident channel: creates it (with a new name when the first is
# taken), invites the responders, sets the topic, opens a direct message with
# the lead, and archives the channel when the incident ends.
module OfflineIncidentChannelExample
  RESPONDERS = %w[U-LEAD U-ONCALL U-GONE]

  # Returns the transport, so a spec can read every recorded request.
  def self.run(output : IO = STDOUT) : Slack::Testing::RecordingTransport
    transport = Slack::Testing::RecordingTransport.new
    queue_responses(transport)
    client = Slack::Api::Client.new(token: "xoxb-synthetic-incident", transport: transport)

    channel = create_channel(client, "incident-42", output)
    # force: invite the valid responders even when one ID is unknown.
    client.call(Slack::Api::ConversationsInvite.new(channel.id, RESPONDERS, force: true))
    output.puts "Invited #{RESPONDERS.size} responders"

    updated = client.call(Slack::Api::ConversationsSetTopic.new(channel.id, "Checkout errors. Updates every 30 min."))
    output.puts "Topic: #{updated.topic["value"]}" if updated.is_a?(Slack::Models::PublicChannel)

    dm = client.call(Slack::Api::ConversationsOpen.new(users: ["U-LEAD"]))
    output.puts "Lead DM: #{dm.channel_id}"

    client.call(Slack::Api::ConversationsArchive.new(channel.id))
    output.puts "Archived #{channel.id}"
    transport
  end

  private def self.create_channel(client : Slack::Api::Client, name : String,
                                  output : IO) : Slack::Models::Conversation
    client.call(Slack::Api::ConversationsCreate.new(name))
  rescue error : Slack::Api::Error
    raise error unless error.code == "name_taken"
    channel = client.call(Slack::Api::ConversationsCreate.new("#{name}-1"))
    output.puts "#{name} is taken; created #{name}-1 (#{channel.id})"
    channel
  end

  # Independently written Slack responses, in call order.
  private def self.queue_responses(transport : Slack::Testing::RecordingTransport) : Nil
    transport.respond(%({"ok":false,"error":"name_taken"}))
      .respond(channel_response(%({"value":"","creator":"","last_set":0})))
      .respond(channel_response(%({"value":"","creator":"","last_set":0})))
      .respond(channel_response(%({"value":"Checkout errors. Updates every 30 min.","creator":"U-BOT","last_set":1789232460})))
      .respond(%({"ok":true,"channel":{"id":"D-LEAD"}}))
      .respond(%({"ok":true}))
  end

  private def self.channel_response(topic : String) : String
    <<-JSON
      {"ok":true,"channel":{"id":"C42","name":"incident-42-1","is_channel":true,"is_private":false,
       "created":1789232400,"creator":"U-BOT","name_normalized":"incident-42-1","previous_names":[],
       "is_member":true,"purpose":{"value":"","creator":"","last_set":0},"topic":#{topic}}}
      JSON
  end
end
