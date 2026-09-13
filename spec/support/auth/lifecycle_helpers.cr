require "./oauth_state_fakes"
require "../../../src/slack/auth/storage/memory_installation_store"

module LifecycleSupport
  API_CONFIGURATION   = Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/custom/api/"))
  OAUTH_CONFIGURATION = Slack::Auth::OAuthConfiguration.new(
    URI.parse("https://authorize.example.test/install"),
    URI.parse("https://token.example.test/custom/oauth.v2.access"),
    "synthetic-client", Slack::Auth::Secret.new("synthetic-client-secret"),
    URI.parse("https://app.example.test/callback?route=install"),
  )

  def self.response(name : String) : Slack::Auth::TransportResponse
    Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      File.read("spec/fixtures/oauth_responses/#{name}.json"))
  end

  def self.install(store : Slack::Auth::InstallationStore,
                   transport : OAuthStateSupport::RecordingTransport,
                   clock : Slack::Auth::Clock) : Slack::Auth::InstallationRecord
    states = Slack::Auth::MemoryStateStore.new(clock)
    handler = Slack::AuthHandler.new(OAUTH_CONFIGURATION, states, transport, clock: clock)
    session = Slack::Auth::Secret.new("synthetic-browser-session")
    state = URI::Params.parse(URI.parse(handler.redirect_url(session)).query || "")["state"]
    callback = HTTP::Request.new("GET", "/callback?#{URI::Params.encode({"state" => state, "code" => "synthetic-code"})}")
    transport.enqueue(response("combined_rotating"))
    installation = handler.authenticate_user(callback, session)
    key = installation.installation_key
    store.store(key, installation.installation_patch(clock), store.fetch(key).try(&.version))
  end

  def self.request(body : String, clock : Slack::Auth::Clock) : HTTP::Request
    timestamp = clock.now.to_unix.to_s
    HTTP::Request.new("POST", "/slack", HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }, body)
  end

  def self.command(clock : Slack::Auth::Clock, team : String = "TTEAM") : HTTP::Request
    request(URI::Params.encode({
      "api_app_id" => "AAPP", "team_id" => team, "is_enterprise_install" => "false",
      "channel_id" => "CCHANNEL", "channel_name" => "general", "command" => "/lifecycle",
      "response_url" => "https://hooks.example.test/synthetic", "team_name" => "Synthetic",
      "text" => "hello", "trigger_id" => "synthetic-trigger", "user_id" => "UUSER", "user_name" => "user",
    }), clock)
  end

  def self.lifecycle_request(clock : Slack::Auth::Clock, uninstall : Bool = false) : HTTP::Request
    event = if uninstall
              {type: "app_uninstalled"}
            else
              {type: "tokens_revoked", tokens: {oauth: ["UUSER"], bot: [] of String}}
            end
    request({
      token: "synthetic-verification-token", api_app_id: "AAPP", team_id: "TTEAM",
      type: "event_callback", event_id: uninstall ? "EvUNINSTALL" : "EvREVOKE",
      event_time: clock.now.to_unix, event: event,
    }.to_json, clock)
  end

  def self.authorizer(store : Slack::Auth::InstallationStore,
                      oauth : OAuthStateSupport::RecordingTransport,
                      api : OAuthStateSupport::RecordingTransport,
                      clock : Slack::Auth::Clock) : Slack::Auth::RequestAuthorizer
    rotation = Slack::Auth::RotationService.new(store,
      Slack::Auth::RefreshClient.new(OAUTH_CONFIGURATION, oauth), clock: clock)
    Slack::Auth::RequestAuthorizer.new("AAPP", store, api, API_CONFIGURATION,
      -> { clock.now }, rotation: rotation)
  end

  def self.send(context : Slack::Auth::RequestContext, api : OAuthStateSupport::RecordingTransport) : Nil
    api.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, %({"ok":true})))
    context.dispatch("POST", "chat.postMessage", body: %({"channel":"CCHANNEL","text":"hello"}))
  end
end
