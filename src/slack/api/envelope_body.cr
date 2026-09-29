require "json"
require "./envelope_metadata"

module Slack::Api
  # :nodoc:
  # The envelope fields alone. `DecodedResponse.envelope_only` reads a body as
  # this type when the body does not decode as the response model, for
  # example an error body without the model's required fields.
  struct EnvelopeBody
    include JSON::Serializable

    getter ok : Bool?
    getter error : String?
    getter warning : String?
    getter response_metadata : EnvelopeMetadata?
    getter errors : JSON::Any?
  end
end
