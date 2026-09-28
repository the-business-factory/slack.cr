require "../../src/slack"
require "../../src/slack/testing"
require "webmock"
require "./webmock_transport"

# Verifies a signed `/deploy` command, answers in the channel with Block Kit,
# and later reports the result through the command's response_url.
module OfflineSlashCommandExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  RESPONSE_URL = "https://hooks.slack.com/commands/T-SYNTHETIC/1234/synthetic"

  # Independently authored form body, as Slack sends it.
  BODY = URI::Params.encode({
    "token"        => "synthetic-legacy-token",
    "team_id"      => "T-SYNTHETIC",
    "team_name"    => "synthetic",
    "channel_id"   => "C-DEPLOYS",
    "channel_name" => "deploys",
    "user_id"      => "U-SYNTHETIC",
    "user_name"    => "synthetic.user",
    "command"      => "/deploy",
    "text"         => "api 42",
    "api_app_id"   => "A-SYNTHETIC",
    "response_url" => RESPONSE_URL,
    "trigger_id"   => "1710000000.synthetic.trigger",
  })

  record Result, acknowledgment : HTTP::Client::Response, follow_up : JSON::Any

  def self.signed : HTTP::Request
    Slack::Testing::SignedRequest.build(BODY, signing_secret: SIGNING_SECRET, path: "/slack/commands", content_type: "application/x-www-form-urlencoded")
  end

  def self.run(output : IO = STDOUT) : Result
    follow_ups = install_transport

    command = Slack::Commands.parse(VERIFIER.verify(signed).body)
    service, build = command.text.split(' ', 2)
    output.puts "#{command.command} #{service} #{build} from #{command.user_id}"

    # Answer within three seconds. The HTTP 200 body is the first message.
    started = UI.message(fallback_text: "Deploying #{service} build #{build}.") do |builder|
      builder.section(UI.mrkdwn("*Deploying #{service}* build #{build}."), block_id: "deploy.status")
    end
    response = Slack::Commands::Response.new(message: started, response_type: :in_channel)
    acknowledgment = HTTP::Client::Response.new(200, body: response.to_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"})

    # Later, replace the first message with the result.
    finished = Slack::Interactions::ResponseUrlMessage.new(text: "Deployed #{service} build #{build}.",
      response_type: :in_channel, replace_original: true)
    Slack::Interactions::ResponseUrlResponder.new(command.response_url)
      .post(OfflineExample::WebMockTransport.new, finished)
    output.puts "Reported result through response_url"

    Result.new(acknowledgment, follow_ups.first? || raise "Missing response_url post")
  end

  # Returns the response_url request bodies in send order.
  private def self.install_transport : Array(JSON::Any)
    WebMock.allow_net_connect = false
    posts = [] of JSON::Any
    WebMock.stub(:post, RESPONSE_URL).with(headers: {"Content-Type" => "application/json"}).to_return do |request|
      posts << JSON.parse(request.body || raise "Missing response_url body")
      HTTP::Client::Response.new(200, body: "ok")
    end
    posts
  end
end
