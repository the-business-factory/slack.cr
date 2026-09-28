# Resolves the installation that owns each request through
# `Auth::RequestAuthorizer#authorize_trusted` and returns the fenced client of
# its `Auth::RequestContext`. The client holds no token: the scoped transport
# reads the credential immediately before each send.
#
# ```
# authorizer = Slack::App::InstallationAuthorizer.new(request_authorizer, Slack::Auth::GrantKey.new(:bot))
# ```
class Slack::App::InstallationAuthorizer < Slack::App::Authorizer
  def initialize(@request_authorizer : Slack::Auth::RequestAuthorizer, @grant : Slack::Auth::GrantKey)
  end

  def authorize(payload : App::Payload) : Slack::Api::Client
    @request_authorizer.authorize_trusted(payload, @grant).client
  end
end
