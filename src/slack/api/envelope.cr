require "json"

module Slack::Api
  # :nodoc:
  # The fields that every Web API response shares.
  struct Envelope
    include JSON::Serializable

    struct Metadata
      include JSON::Serializable

      getter messages : Array(String)?
      getter warnings : Array(String)?
      getter next_cursor : String?
    end

    getter? ok : Bool
    getter error : String?
    getter warning : String?
    getter response_metadata : Metadata?
    # Raw, because methods give different entry shapes; `Response` reads the
    # entries that have a string `message`.
    getter errors : JSON::Any?
  end
end
