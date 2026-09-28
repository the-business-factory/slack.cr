require "../../src/slack"
require "../../src/slack/testing"

# Tests an application's `/standup` handler offline: a signed request goes in,
# and the recording transport captures the chat.postMessage call that comes out.
module OfflineTestingExample
  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")

  # Application code under test. It verifies the request before it reads the
  # command or calls Slack.
  class StandupHandler
    def initialize(@verifier : Slack::Webhooks::Verifier, @client : Slack::Api::Client)
    end

    def handle(request : HTTP::Request) : Nil
      command = Slack::Commands.parse(@verifier.verify(request).body)
      @client.call(Slack::Api::ChatPostMessage.new(channel: command.channel_id,
        text: "<@#{command.user_id}> starts the standup: #{command.text}"))
    end
  end

  # Independently authored form body, as Slack sends it.
  BODY = URI::Params.encode({
    "team_id"      => "T-SYNTHETIC",
    "channel_id"   => "C-TEAM",
    "channel_name" => "team",
    "user_id"      => "U-SYNTHETIC",
    "user_name"    => "synthetic.user",
    "command"      => "/standup",
    "text"         => "blockers first",
    "api_app_id"   => "A-SYNTHETIC",
    "response_url" => "https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic",
    "trigger_id"   => "1710000000.synthetic.trigger",
  })

  # Returns the transport, so a spec can read every recorded request.
  def self.run(output : IO = STDOUT) : Slack::Testing::RecordingTransport
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(<<-JSON)
      {"ok":true,"channel":"C-TEAM","ts":"1710000000.000100",
       "message":{"type":"message","ts":"1710000000.000100","text":"Standup started"}}
      JSON
    client = Slack::Api::Client.new(token: "xoxb-synthetic-testing", transport: transport)
    handler = StandupHandler.new(Slack::Webhooks::Verifier.new(SIGNING_SECRET), client)

    handler.handle(Slack::Testing::SignedRequest.build(BODY, signing_secret: SIGNING_SECRET,
      path: "/slack/commands", content_type: "application/x-www-form-urlencoded"))
    sent = transport.requests.last
    output.puts "#{sent.uri.path} #{sent.body}"

    forged = Slack::Testing::SignedRequest.build(BODY, signing_secret: Slack::Auth::Secret.new("wrong-secret"),
      path: "/slack/commands", content_type: "application/x-www-form-urlencoded")
    begin
      handler.handle(forged)
    rescue Slack::Errors::SignatureMismatch
      output.puts "Rejected a forged request; Slack calls: #{transport.requests.size}"
    end
    transport
  end
end
