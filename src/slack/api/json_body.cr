module Slack::Api
  # Encodes a request as an `application/json` body through its `to_json`.
  module JsonBody
    def content_type : String
      "application/json; charset=utf-8"
    end

    def encode(io : IO) : Nil
      to_json(io)
    end
  end
end
