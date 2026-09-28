require "json"
require "uri"
require "./request"
require "./form_body"

module Slack::Api
  # :nodoc:
  # Any Web API method as form fields, like Bolt's `apiCall`. Strings are sent
  # unchanged, other values as JSON text, and nil values are omitted.
  struct GenericRequest < Request(JSON::Any)
    include FormBody

    getter method_path : String
    getter tier : RateLimitTier
    getter form : URI::Params

    def initialize(@method_path : String, params : NamedTuple | Hash, @tier : RateLimitTier)
      @form = URI::Params.new
      params.each do |key, value|
        # Parsed JSON arguments carry the same wire values as native ones.
        value = value.raw if value.is_a?(JSON::Any)
        next if value.nil?
        @form.add(key.to_s, value.is_a?(String) ? value : value.to_json)
      end
    end
  end
end
