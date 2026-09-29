require "json"
require "./envelope"

module Slack::Api
  # :nodoc:
  # The envelope fields alone. `Response` reads a body as this type only when
  # the model does not decode, for example an error body without the model's
  # required fields, and for raw JSON responses.
  struct EnvelopeBody
    include JSON::Serializable
    include Envelope

    private KEYS = {"ok", "error", "warning", "response_metadata", "errors"}

    # Reads the envelope fields of a parsed response. Only these fields are
    # serialized again, so the cost does not grow with the response size.
    def self.new(raw : JSON::Any) : self
      fields = raw.as_h? || raise JSON::ParseException.new("Response must be an object", 0, 0)
      from_json(fields.select(KEYS).to_json)
    end
  end
end
