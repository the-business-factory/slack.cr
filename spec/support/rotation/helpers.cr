require "../../../src/slack/auth/rotation_service"
require "../../../src/slack/auth/storage/memory_installation_store"
require "../storage/clock"

module RotationSupport
  extend self

  def configuration : Slack::Auth::OAuthConfiguration
    Slack::Auth::OAuthConfiguration.new(URI.parse("https://example.test/authorize"),
      URI.parse("https://example.test/custom/token"), "synthetic-client", Slack::Auth::Secret.new("synthetic-secret"),
      URI.parse("https://example.test/callback"))
  end

  def query(user : String? = nil) : Slack::Auth::InstallationQuery
    key = Slack::Auth::InstallationKey.new("A1", :workspace, team_id: "T1")
    kind = user ? Slack::Auth::TokenKind::User : Slack::Auth::TokenKind::Bot
    Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(kind, user))
  end

  def grant(subject : String, expires_at : Time? = nil, refresh : String? = "synthetic-refresh") : Slack::Auth::Grant
    Slack::Auth::Grant.new(subject, Slack::Auth::Secret.new("synthetic-old-#{subject}"), ["chat:write"],
      expires_at, refresh.try { |value| Slack::Auth::Secret.new(value) })
  end

  def seed(store : Slack::Auth::InstallationStore, now : Time) : Slack::Auth::InstallationRecord
    store.store(query.owner, Slack::Auth::InstallationPatch.new(bot: grant("B1", now + 5.minutes),
      users: {"U1" => grant("U1", now + 5.minutes), "U2" => grant("U2", now + 1.hour)}), nil)
  end

  def response(kind : String = "bot") : Slack::Auth::TransportResponse
    Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      File.read("spec/fixtures/oauth_responses/refresh_#{kind}.json"))
  end

  def service(store : Slack::Auth::InstallationStore, transport : Slack::Auth::Transport,
              clock : Slack::Auth::Clock) : Slack::Auth::RotationService
    Slack::Auth::RotationService.new(store, Slack::Auth::RefreshClient.new(configuration, transport), clock: clock)
  end

  class Transport < Slack::Auth::Transport
    getter requests = [] of Slack::Auth::TransportRequest
    property response : Slack::Auth::TransportResponse = RotationSupport.response
    property before_response : Proc(Nil)? = nil

    def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
      @requests << request
      @before_response.try(&.call)
      @response
    end
  end
end
