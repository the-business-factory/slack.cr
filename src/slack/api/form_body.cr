require "uri"

module Slack::Api
  # Encodes a request as `application/x-www-form-urlencoded` fields.
  module FormBody
    abstract def form : URI::Params

    def content_type : String
      "application/x-www-form-urlencoded"
    end

    def encode(io : IO) : Nil
      form.to_s(io)
    end
  end
end
