# Uses one client for every request: an app installed in one workspace.
#
# ```
# client = Slack::Api::Client.new(token: Slack::Auth::Secret.new(ENV["SLACK_BOT_TOKEN"]))
# authorizer = Slack::App::SingleTokenAuthorizer.new(client)
# ```
class Slack::App::SingleTokenAuthorizer < Slack::App::Authorizer
  def initialize(@client : Slack::Api::Client)
  end

  def authorize(payload : App::Payload) : Slack::Api::Client
    @client
  end
end
