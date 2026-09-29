require "json"
require "./envelope_metadata"
require "./envelope_body"

module Slack::Api
  # :nodoc:
  # The decoded Web API response body: the envelope values and, when the body
  # decodes as the model, the model. `Response` classifies the envelope before
  # it uses the model, so an error body that does not match the model still
  # gives its Slack error.
  struct DecodedResponse(M)
    getter model : M?
    # Nil when the body has no boolean `ok`, or does not parse.
    getter ok : Bool?
    getter error : String?
    getter warning : String?
    getter response_metadata : EnvelopeMetadata?
    # Raw, because methods give different entry shapes; `Response` reads the
    # entries that have a string `message`.
    getter errors : JSON::Any?
    # True when the model marks an `ok: false` response as a documented outcome.
    getter? flagged_outcome : Bool

    def initialize(@model : M?, @ok : Bool?, @error : String?, @warning : String?,
                   @response_metadata : EnvelopeMetadata?, @errors : JSON::Any?, @flagged_outcome : Bool)
    end

    # A body that does not parse, with no model and no envelope values.
    def self.unreadable : self
      new(nil, nil, nil, nil, nil, nil, false)
    end

    # Reads the envelope fields alone, for a body that does not decode as the
    # model. This is a second parse, so only such bodies, which are usually
    # small error bodies, pay for it.
    def self.envelope_only(body : String) : self
      envelope = EnvelopeBody.from_json(body)
      new(nil, envelope.ok, envelope.error, envelope.warning, envelope.response_metadata, envelope.errors, false)
    rescue JSON::ParseException
      unreadable
    end

    # Reads the envelope values from a parsed raw response. A value of the
    # wrong JSON type makes the whole body unreadable, as it does for a model.
    def self.new(raw : JSON::Any) : self
      fields = raw.as_h?
      return unreadable unless fields
      ok = fields["ok"]?.try(&.as_bool?)
      return unreadable if ok.nil?

      metadata = EnvelopeMetadata.from_raw(fields["response_metadata"]?)
      new(raw, ok, string?(fields, "error"), string?(fields, "warning"), metadata, fields["errors"]?, false)
    rescue JSON::ParseException
      unreadable
    end

    # Replaces the model, for a response that holds its model under a key.
    def map(& : M -> T) : DecodedResponse(T) forall T
      model = @model
      DecodedResponse(T).new(model.try { |value| yield value }, @ok, @error, @warning, @response_metadata,
        @errors, @flagged_outcome)
    end

    private def self.string?(fields : Hash(String, JSON::Any), key : String) : String?
      value = fields[key]?
      return if value.nil? || value.raw.nil?
      value.as_s? || raise JSON::ParseException.new("Expected a string for #{key}", 0, 0)
    end
  end
end
