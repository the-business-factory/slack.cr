require "../../src/slack"
require "../../src/slack/testing"

# Serves a signed `assistant_thread_started` event and a user message in the
# thread through `Slack::App::HttpReceiver`. The assistant greets the user,
# suggests a prompt, and streams an answer with a status. A recording
# transport answers the Web API calls.
module OfflineAssistantExample
  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")

  # Independently authored from the assistant_thread_started and message.im references.
  STARTED  = %q({"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC","event":{"type":"assistant_thread_started","assistant_thread":{"user_id":"U-USER","channel_id":"D-ASSISTANT","thread_ts":"1729999327.187299","context":{"channel_id":"C-SALES","team_id":"T-SYNTHETIC"}},"event_ts":"1729999327.187299"},"type":"event_callback","event_id":"Ev-STARTED","event_time":1729999327,"authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]})
  QUESTION = %q({"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC","event":{"type":"message","user":"U-USER","text":"Summarize this channel.","ts":"1729999500.000100","thread_ts":"1729999327.187299","channel":"D-ASSISTANT","channel_type":"im","team":"T-SYNTHETIC","event_ts":"1729999500.000100"},"type":"event_callback","event_id":"Ev-QUESTION","event_time":1729999500,"authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]})

  # Independently authored from the conversations.replies reference: the
  # thread root, the app's greeting with the saved context, and the question.
  REPLIES = %q({"ok":true,"has_more":false,"messages":[{"type":"message","subtype":"assistant_app_thread","user":"U-USER","text":"New chat","ts":"1729999327.187299","thread_ts":"1729999327.187299"},{"type":"message","user":"U-BOT","bot_id":"B-SYNTHETIC","text":"Hi! Ask me about a channel.","ts":"1729999328.000100","thread_ts":"1729999327.187299","metadata":{"event_type":"assistant_thread_context","event_payload":{"channel_id":"C-SALES","team_id":"T-SYNTHETIC"}}},{"type":"message","user":"U-USER","text":"Summarize this channel.","ts":"1729999500.000100","thread_ts":"1729999327.187299"}]})
  STREAM  = %q({"ok":true,"channel":"D-ASSISTANT","ts":"1729999501.000100"})

  def self.build_assistant(done : Channel(Nil)) : Slack::App::Assistant
    assistant = Slack::App::Assistant.new

    assistant.thread_started do |ctx|
      ctx.say("Hi! Ask me about a channel.")
      ctx.set_suggested_prompts([Slack::Api::SuggestedPrompt.new("Summarize", "Summarize this channel.")])
      done.send(nil)
    end

    assistant.user_message do |ctx|
      ctx.set_status("is thinking...")
      channel = ctx.thread_context.try(&.channel_id) || "this conversation"
      # Application code calls its language model here.
      ctx.stream do |stream|
        stream.append(ctx.client, markdown_text: "Summary of <##{channel}>: sales grew 4%.")
      end
      done.send(nil)
    end
    assistant
  end

  def self.run(output : IO = STDOUT) : Array(Slack::Auth::TransportRequest)
    transport = Slack::Testing::RecordingTransport.new
    posted = %q({"ok":true,"channel":"D-ASSISTANT","ts":"1729999328.000100","message":{"type":"message","text":"Hi! Ask me about a channel.","ts":"1729999328.000100"}})
    [posted, %({"ok":true}), %({"ok":true}), REPLIES, REPLIES, STREAM, STREAM, STREAM].each { |body| transport.respond(body) }
    client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic-assistant"), transport: transport)
    app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))
    done = Channel(Nil).new(1)
    app.assistant(build_assistant(done))
    # In an application: HTTP::Server.new([receiver]).listen(3000)
    receiver = Slack::App::HttpReceiver.new(app, Slack::Webhooks::Verifier.new(SIGNING_SECRET))

    {STARTED, QUESTION}.each do |body|
      serve(receiver, Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET))
      done.receive
    end
    transport.requests.each { |request| output.puts request.uri.path.lchop("/api/") }
    transport.requests
  end

  # Runs one request through the handler in memory, as `HTTP::Server` would.
  private def self.serve(handler : HTTP::Handler, request : HTTP::Request) : Nil
    response = HTTP::Server::Response.new(IO::Memory.new)
    handler.call(HTTP::Server::Context.new(request, response))
    response.close
  end
end
