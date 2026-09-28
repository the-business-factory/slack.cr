# Uses one client for every request: an app installed in one workspace.
#
# ```
# client = Slack::Api::Client.new(token: Slack::Auth::Secret.new(ENV["SLACK_BOT_TOKEN"]))
# authorizer = Slack::App::SingleTokenAuthorizer.new(client)
# ```
#
# The client has one token, for *grant* (the bot by default). A request for
# any other grant raises `GrantUnavailable`.
class Slack::App::SingleTokenAuthorizer < Slack::App::Authorizer
  def initialize(@client : Slack::Api::Client, @grant : Slack::Auth::GrantKey = Slack::Auth::GrantKey.new(:bot))
  end

  def authorize(payload : App::Payload) : Slack::Api::Client
    @client
  end

  def authorize(payload : App::Payload, grant : Slack::Auth::GrantKey) : Slack::Api::Client
    raise GrantUnavailable.new(App.describe(payload), grant) unless grant == @grant
    @client
  end
end
