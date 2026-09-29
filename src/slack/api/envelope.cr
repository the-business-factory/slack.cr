require "json"
require "./envelope_metadata"
require "./decoded_response"

module Slack::Api
  # :nodoc:
  # The fields that every Web API response shares, for inclusion in a
  # `JSON::Serializable` response model. Slack sends these fields next to the
  # model fields, so `Response` reads both from one parse of the body.
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
      # Parses a Web API response body once into its envelope values and, when
      # the body has the model's required fields, the model.
      #
      # An error body, such as `{"ok": false, "error": "channel_not_found"}`,
      # has none of the model's required fields. The `JSON::Serializable`
      # constructor reads every key, then assigns the fields in order and
      # raises at the first missing required field. The compiler orders the
      # fields of an included module before the type's own fields, so the
      # envelope fields are assigned first. This method runs that constructor
      # on its own instance and reads them from the partial instance after the
      # raise. It never returns the partial instance. `spec/api/response_spec.cr`
      # checks this for the model of every typed request.
      def self.from_api_response(body : String) : ::Slack::Api::DecodedResponse(self)
        instance = allocate
        model = begin
          instance.initialize(__pull_for_json_serializable: ::JSON::PullParser.new(body))
          instance
        rescue ::JSON::ParseException | ::TypeCastError | ::ArgumentError
          # Converters such as String#to_f raise ArgumentError with the remote
          # value in the message; the caller reports only `invalid_response`.
          nil
        end
        ::Slack::Api::DecodedResponse(self).new(model, instance.@ok, instance.@error, instance.@warning,
          instance.@response_metadata, instance.@errors, model.try(&.flagged_outcome?) || false)
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
