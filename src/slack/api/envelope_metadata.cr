require "json"

module Slack::Api
  # :nodoc:
  # The `response_metadata` object of a Web API response.
  # See https://docs.slack.dev/apis/web-api/pagination.
  struct EnvelopeMetadata
    include JSON::Serializable

    getter messages : Array(String)?
    getter warnings : Array(String)?
    getter next_cursor : String?

    def initialize(@messages : Array(String)?, @warnings : Array(String)?, @next_cursor : String?)
    end

    # Reads the object from a parsed raw response. Returns nil for an absent
    # or null value. Raises `JSON::ParseException` for a value of the wrong type.
    def self.from_raw(value : JSON::Any?) : self?
      return if value.nil? || value.raw.nil?
      fields = value.as_h? || raise JSON::ParseException.new("Expected an object for response_metadata", 0, 0)
      new(strings?(fields["messages"]?), strings?(fields["warnings"]?), string?(fields["next_cursor"]?))
    end

    private def self.strings?(value : JSON::Any?) : Array(String)?
      return if value.nil? || value.raw.nil?
      entries = value.as_a? || raise JSON::ParseException.new("Expected an array in response_metadata", 0, 0)
      entries.map { |entry| string?(entry) || raise JSON::ParseException.new("Expected a string in response_metadata", 0, 0) }
    end

    private def self.string?(value : JSON::Any?) : String?
      return if value.nil? || value.raw.nil?
      value.as_s? || raise JSON::ParseException.new("Expected a string in response_metadata", 0, 0)
    end
  end
end
