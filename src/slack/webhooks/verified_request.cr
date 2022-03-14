# https://api.slack.com/authentication/verifying-requests-from-slack
class Slack::Webhooks::VerifiedRequest
  getter request : HTTP::Request
  getter slack_signature : String
  getter slack_timestamp : String
  getter body : String

  delegate signing_secret, to: Slack.settings
  delegate signing_secret_version, to: Slack.settings
  delegate webhook_delivery_time_limit, to: Slack.settings

  def initialize(@request : HTTP::Request)
    @slack_timestamp = @request.headers["X-Slack-Request-Timestamp"]
    @slack_signature = @request.headers["X-Slack-Signature"]
    @body = @request.body.not_nil!.gets_to_end
  end

  def verify!
    raise Errors::ReplayAttack.new if replay_attack?
    raise Errors::SignatureMismatch.new unless signature_matches?
    self
  end

  def signature_matches?
    slack_signature == Signature
      .new(slack_timestamp: slack_timestamp, body: body)
      .compute
  end

  def replay_attack?
    Time.unix(slack_timestamp.to_i) < webhook_delivery_time_limit.ago
  end
end
