require "../../../src/slack/auth/request_authorizer"
require "../../../src/slack/auth/storage/memory_installation_store"

class RequestAuthorizerConsumerTransport < Slack::Auth::Transport
  def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
    raise "missing fenced credential" unless request.headers["Authorization"]? == "Bearer synthetic-bot-token"
    Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, %({"ok":true}))
  end
end

store = Slack::Auth::MemoryInstallationStore.new
key = Slack::Auth::InstallationKey.new("A1", :workspace, team_id: "T1")
store.store(key, Slack::Auth::InstallationPatch.new(
  bot: Slack::Auth::Grant.new("U_BOT", Slack::Auth::Secret.new("synthetic-bot-token"), [] of String)
), nil)

authorizer = Slack::Auth::RequestAuthorizer.new(
  "A1",
  store,
  RequestAuthorizerConsumerTransport.new,
  Slack::Auth::APIConfiguration.new(URI.parse("https://slack.example/api/")),
)
command = Slack::Commands::Parser.parse(URI::Params.encode({
  "api_app_id"            => "A1",
  "channel_id"            => "C1",
  "channel_name"          => "general",
  "command"               => "/example",
  "is_enterprise_install" => "false",
  "response_url"          => "https://hooks.slack.example/synthetic",
  "team_id"               => "T1",
  "team_name"             => "Example",
  "text"                  => "",
  "trigger_id"            => "synthetic-trigger",
  "user_id"               => "U_ACTOR",
  "user_name"             => "actor",
}))
context = authorizer.authorize_trusted(command, Slack::Auth::GrantKey.new(:bot))
context.dispatch("POST", "chat.postMessage")
puts context.query.owner.team_id
