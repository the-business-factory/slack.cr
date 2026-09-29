require "uri"
require "../auth/request_authorization_error"

module Slack::Interactions
  # Decodes a verified interaction form body. The body must have exactly one
  # `payload` field; otherwise this raises `Slack::Auth::RequestAuthorizationError`
  # with `invalid_payload`. Pass only a body that `Slack::Webhooks::Verifier#verify` returned.
  def self.parse(body : String) : Slack::Interaction
    Slack::Interaction.from_json(form_payload(body))
  end

  # :nodoc:
  # Returns the JSON in the one `payload` field of an interaction form body.
  # Raises `Slack::Auth::RequestAuthorizationError` with `invalid_payload`
  # when the body does not have exactly one `payload` field.
  def self.form_payload(body : String) : String
    payloads = URI::Params.parse(body).fetch_all("payload")
    raise Slack::Auth::RequestAuthorizationError.new(:invalid_payload) unless payloads.size == 1
    payloads.first
  end
end
