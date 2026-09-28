# Raised by `SingleTokenAuthorizer` when a listener asks for a client for a
# grant other than the one its token belongs to. The message names the payload
# kind and the grant; it holds no token.
class Slack::App::GrantUnavailable < Exception
  getter payload_kind : String
  getter grant : Slack::Auth::GrantKey

  def initialize(@payload_kind : String, @grant : Slack::Auth::GrantKey)
    super("No client for the #{describe(grant)} for #{payload_kind}")
  end

  private def describe(grant : Slack::Auth::GrantKey) : String
    user_id = grant.user_id
    user_id ? "#{grant.kind.to_s.downcase} grant of #{user_id}" : "#{grant.kind.to_s.downcase} grant"
  end
end
