require "uri"
require "../auth/request_authorization_error"

module Slack::Interactions
  # Decodes a verified interaction form body. The body must have exactly one
  # `payload` field; otherwise this raises `Slack::Auth::RequestAuthorizationError`
  # with `invalid_payload`. Pass only a body that `Slack::Webhooks::Verifier#verify` returned.
  def self.parse(body : String) : Slack::Interaction
    payloads = URI::Params.parse(body).fetch_all("payload")
    raise Slack::Auth::RequestAuthorizationError.new(:invalid_payload) unless payloads.size == 1
    Slack::Interaction.from_json(payloads.first)
  end
end
