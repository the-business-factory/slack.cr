struct Slack::Webhooks::Signature
  delegate signing_secret, to: Slack.settings
  delegate signing_secret_version, to: Slack.settings

  def initialize(@slack_timestamp : String, @body : String)
  end

  def basestring : String
    [signing_secret_version, @slack_timestamp, @body].join(":")
  end

  def compute
    hex_hash = OpenSSL::HMAC.hexdigest(:sha256, required_signing_secret, basestring)
    [signing_secret_version, hex_hash].join("=")
  end

  private def required_signing_secret : String
    value = signing_secret
    raise Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::InvalidConfiguration) if value.nil? || value.blank?
    value
  end
end
