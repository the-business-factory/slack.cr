require "json"

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
    struct Metadata
      include JSON::Serializable

      getter messages : Array(String)?
      getter warnings : Array(String)?
      getter next_cursor : String?
    end

    @[JSON::Field(key: "ok")]
    @ok : Bool? = nil
    getter error : String? = nil
    getter warning : String? = nil
    getter response_metadata : Metadata? = nil
    # Raw, because methods give different entry shapes; `Response` reads the
    # entries that have a string `message`.
    getter errors : JSON::Any? = nil

    macro included
      # :nodoc:
      # Decodes a Web API response body into the model and its envelope fields.
      def self.from_api_response(body : String) : {self, ::Slack::Api::Envelope}
        model = from_json(body)
        {model, model}
      end
    end

    # True when Slack answered `"ok": true`.
    def ok? : Bool
      @ok == true
    end

    def ok_present? : Bool
      !@ok.nil?
    end

    # True when an `ok: false` response without `error` is a documented outcome
    # of the method, not a failure. Override it in the model that carries the
    # outcome field, such as `Conversations::LeaveResponse#not_in_channel?`.
    def flagged_outcome? : Bool
      false
    end
  end
end
