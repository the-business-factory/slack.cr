require "json"
require "./envelope_metadata"
require "./decoded_response"

module Slack::Api
  # :nodoc:
  # The fields that every Web API response shares, for inclusion in a
  # `JSON::Serializable` response model. Slack sends these fields next to the
  # model fields, so `Response` reads both from one parse of a success body.
  #
  # Every field is optional, because a model can also occur nested in a list,
  # such as a `reactions.get` item inside `reactions.list`. `Response` rejects
  # a body without `ok`.
  module Envelope
    @[JSON::Field(key: "ok")]
    @ok : Bool? = nil
    getter error : String? = nil
    getter warning : String? = nil
    getter response_metadata : EnvelopeMetadata? = nil
    # Kept for `Api::Error#details`, not exposed.
    @errors : JSON::Any? = nil

    macro included
      # :nodoc:
      # Decodes a Web API response body. A success body parses once, as the
      # model with its envelope fields. When the body does not decode as the
      # model, such as an error body without the model's required fields, the
      # envelope fields are parsed again alone, so the Slack error survives.
      def self.from_api_response(body : String) : ::Slack::Api::DecodedResponse(self)
        model = from_json(body)
        ::Slack::Api::DecodedResponse(self).new(model, model.@ok, model.@error, model.@warning,
          model.@response_metadata, model.@errors, model.flagged_outcome?)
      rescue ::JSON::ParseException | ::TypeCastError | ::ArgumentError
        # Converters such as String#to_f raise ArgumentError with the remote
        # value in the message; `Response` reports only `invalid_response`.
        ::Slack::Api::DecodedResponse(self).envelope_only(body)
      end
    end

    # True when Slack answered `"ok": true`.
    def ok? : Bool
      @ok == true
    end

    # True when an `ok: false` response without `error` is a documented outcome
    # of the method, not a failure. Override it in the model that carries the
    # outcome field, such as `Conversations::LeaveResponse`.
    protected def flagged_outcome? : Bool
      false
    end
  end
end
