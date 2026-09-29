require "../../src/slack"
require "webmock"
require "./webmock_transport"
require "../../src/slack/testing"

# Serves a signed app_mention and a button click through `Slack::App::HttpReceiver`.
# The mention listener posts a message with an Approve button; the click
# listener acknowledges and posts the result. Web API calls reach WebMock.
module OfflineAppExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  # One value names the Approve button and its listener.
  APPROVE = UI::ActionId.new("deploy.approve")

  # Independently authored from the app_mention and block_actions references.
  MENTION = %q({"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC","event":{"type":"app_mention","user":"U-SYNTHETIC","text":"<@U-BOT> deploy api","ts":"1789232400.000100","channel":"C-DEPLOYS","event_ts":"1789232400.000100"},"type":"event_callback","event_id":"Ev-MENTION","event_time":1789232400,"authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]})
  CLICK   = %q({"type":"block_actions","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},"user":{"id":"U-APPROVER","team_id":"T-SYNTHETIC"},"trigger_id":"1789232401.synthetic.trigger","container":{"type":"message","message_ts":"1789232400.000200","channel_id":"C-DEPLOYS","is_ephemeral":false},"channel":{"id":"C-DEPLOYS","name":"deploys"},"actions":[{"type":"button","action_id":"deploy.approve","block_id":"deploy.controls","text":{"type":"plain_text","text":"Approve"},"value":"api","action_ts":"1789232401.000001"}]})

  record Result, mention : HTTP::Client::Response, click : HTTP::Client::Response, posts : Array(JSON::Any)

  def self.build_app : Slack::App
    client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic-app"),
      transport: OfflineExample::WebMockTransport.new)
    app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))

    app.event("app_mention") do |ctx|
      mention = ctx.event
      next unless mention.is_a?(Slack::Events::AppMentioned)
      ctx.client.call(Slack::Api::ChatPostMessage.new(channel: mention.channel, message: approval_request("api")))
    end

    app.action(APPROVE) do |ctx|
      ctx.ack
      button = ctx.action
      channel = ctx.payload.channel
      next unless button.is_a?(Slack::Interactions::ButtonAction) && channel
      ctx.client.call(Slack::Api::ChatPostMessage.new(channel: channel.id,
        text: "#{button.value} approved by <@#{ctx.payload.user.try(&.id)}>."))
    end
    app
  end

  def self.run(output : IO = STDOUT) : Result
    posts = install_web_api
    # In an application: HTTP::Server.new([receiver, *other_handlers]).listen(3000)
    receiver = Slack::App::HttpReceiver.new(build_app, Slack::Webhooks::Verifier.new(SIGNING_SECRET))

    mention = serve(receiver, signed("application/json", MENTION))
    output.puts "Mention acknowledged: #{mention.status_code}"
    first = posts.receive
    click = serve(receiver, signed("application/x-www-form-urlencoded", URI::Params.encode({"payload" => CLICK})))
    output.puts "Click acknowledged: #{click.status_code}"
    Result.new(mention, click, [first, posts.receive])
  end

  def self.approval_request(service : String) : UI::Message
    UI.message(fallback_text: "Approve the #{service} deploy?") do |builder|
      builder.section(UI.mrkdwn("Approve the *#{service}* deploy?"), block_id: "deploy.summary")
      approve = UI::BlockElements::Button.new(text: UI.plain("Approve"), action_id: APPROVE, value: service)
      builder.actions(elements: [approve], block_id: "deploy.controls")
    end
  end

  private def self.signed(content_type : String, body : String) : HTTP::Request
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "Content-Type"              => content_type,
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(SIGNING_SECRET, timestamp, body).compute,
    }
    HTTP::Request.new("POST", "/slack/events", headers, body)
  end

  # Runs one request through the handler in memory, as `HTTP::Server` would.
  private def self.serve(handler : HTTP::Handler, request : HTTP::Request) : HTTP::Client::Response
    output = IO::Memory.new
    response = HTTP::Server::Response.new(output)
    handler.call(HTTP::Server::Context.new(request, response))
    response.close
    HTTP::Client::Response.from_io(output.rewind)
  end

  # Returns a channel that receives each chat.postMessage body in send order.
  private def self.install_web_api : Channel(JSON::Any)
    WebMock.allow_net_connect = false
    posts = Channel(JSON::Any).new(2)
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic-app"})
      .to_return do |request|
        posts.send(JSON.parse(request.body || raise "Missing chat.postMessage body"))
        HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-DEPLOYS","ts":"1789232400.000200"}))
      end
    posts
  end

  # Independently authored from the slash command reference.
  COMMAND = {"token" => "synthetic-legacy-token", "team_id" => "T-SYNTHETIC", "team_name" => "synthetic",
             "channel_id" => "C-DEPLOYS", "channel_name" => "deploys", "user_id" => "U-SYNTHETIC",
             "user_name" => "synthetic.user", "command" => "/deploy", "text" => "api", "api_app_id" => "A-SYNTHETIC",
             "response_url" => "https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic",
             "trigger_id" => "1789232400.synthetic.trigger"}

  record Replies, acknowledgment : HTTP::Client::Response, requests : Array(Slack::Auth::TransportRequest)

  # Serves a signed `/deploy api` command. The listener acknowledges, says a
  # message in the command's channel, and responds privately through the
  # command's response_url. One recording transport answers both.
  def self.run_replies(output : IO = STDOUT) : Replies
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":true,"channel":"C-DEPLOYS","ts":"1789232400.000300","message":{"type":"message","text":"Deploying api.","ts":"1789232400.000300"}}))
    transport.respond("ok")
    done = Channel(Nil).new(1)
    receiver = Slack::App::HttpReceiver.new(build_reply_app(transport, done), Slack::Webhooks::Verifier.new(SIGNING_SECRET))

    acknowledgment = serve(receiver, signed("application/x-www-form-urlencoded", URI::Params.encode(COMMAND)))
    done.receive
    output.puts "Command acknowledged: #{acknowledgment.status_code}"
    output.puts "Sent #{transport.requests.size} replies"
    Replies.new(acknowledgment, transport.requests)
  end

  def self.build_reply_app(transport : Slack::Auth::Transport, done : Channel(Nil)) : Slack::App
    client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic-app"), transport: transport)
    app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client), response_url_transport: transport)
    app.error { |error, ctx| ctx.log.error { error.message } }

    app.command("/deploy") do |ctx|
      ctx.ack
      ctx.say("Deploying #{ctx.command.text}.")
      ctx.respond(Slack::Interactions::ResponseUrlMessage.new(text: "Only you can see this: deploy queued."))
    ensure
      done.send(nil)
    end
    app
  end

  record UserActions, acknowledgment : HTTP::Client::Response, requests : Array(Slack::Auth::TransportRequest)

  # Serves the signed Approve click to an app that authorizes each request from
  # an installation store. The listener adds a reaction to the request message
  # as the approving user, with that user's token, and posts the result with
  # the bot token. One recording transport answers both calls.
  def self.run_as_user(output : IO = STDOUT) : UserActions
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":true}))
    transport.respond(%({"ok":true,"channel":"C-DEPLOYS","ts":"1789232401.000300","message":{"type":"message","text":"api approved.","ts":"1789232401.000300"}}))
    done = Channel(Nil).new(1)
    verifier = Slack::Webhooks::Verifier.new(SIGNING_SECRET)
    receiver = Slack::App::HttpReceiver.new(build_user_app(transport, verifier, done), verifier)

    acknowledgment = serve(receiver, signed("application/x-www-form-urlencoded", URI::Params.encode({"payload" => CLICK})))
    done.receive
    output.puts "Click acknowledged: #{acknowledgment.status_code}"
    output.puts "Reacted as the approver and posted as the bot"
    UserActions.new(acknowledgment, transport.requests)
  end

  def self.build_user_app(transport : Slack::Auth::Transport, verifier : Slack::Webhooks::Verifier,
                          done : Channel(Nil)) : Slack::App
    request_authorizer = Slack::Auth::RequestAuthorizer.new("A-SYNTHETIC", installed_store, transport,
      Slack::Auth::APIConfiguration.default, verifier)
    app = Slack::App.new(authorizer: Slack::App::InstallationAuthorizer.new(request_authorizer, Slack::Auth::GrantKey.new(:bot)))
    app.error { |error, ctx| ctx.log.error { error.message } }

    app.action(APPROVE) do |ctx|
      ctx.ack
      approver = ctx.payload.user.try(&.id)
      message = ctx.payload.container
      next unless approver && message.is_a?(Slack::Interactions::Container::Message)
      # Needs the reactions:write user scope in the approver's install.
      as_approver = ctx.client(Slack::Auth::GrantKey.new(:user, approver))
      as_approver.call(Slack::Api::ReactionsAdd.new(message.channel_id, "white_check_mark", message.message_ts))
      ctx.client.call(Slack::Api::ChatPostMessage.new(channel: message.channel_id, text: "api approved by <@#{approver}>."))
    ensure
      done.send(nil)
    end
    app
  end

  # One installation with a bot grant and the approver's user grant, as the
  # application stores them from the `AuthResponse` of an install that asks
  # for user scopes.
  private def self.installed_store : Slack::Auth::MemoryInstallationStore
    owner = Slack::Auth::InstallationKey.new("A-SYNTHETIC", :workspace, team_id: "T-SYNTHETIC")
    bot = Slack::Auth::Grant.new("U-BOT", Slack::Auth::Secret.new("xoxb-synthetic-app"), ["chat:write"])
    approver = Slack::Auth::Grant.new("U-APPROVER", Slack::Auth::Secret.new("xoxp-synthetic-approver"), ["reactions:write"])
    store = Slack::Auth::MemoryInstallationStore.new
    store.store(owner, Slack::Auth::InstallationPatch.new(bot: bot, users: {"U-APPROVER" => approver}), nil)
    store
  end
end
