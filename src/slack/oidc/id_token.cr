require "json"
require "./base64_url"

module Slack::OIDC
  # :nodoc:
  # The three segments of a compact JWS, split and decoded. Nothing here is
  # checked or trusted: `IDTokenVerifier` reads the header to select the key,
  # and parses the payload only after the signature verifies.
  struct IDToken
    getter algorithm : String?
    getter kid : String?
    getter? critical : Bool
    # The bytes of `header.payload`, as the signer signed them.
    getter signing_input : Bytes
    getter signature : Bytes
    getter payload : Bytes

    def initialize(@algorithm : String?, @kid : String?, @critical : Bool, @signing_input : Bytes,
                   @signature : Bytes, @payload : Bytes)
    end

    # Returns nil unless *token* has three strict base64url segments and the
    # header is a UTF-8 JSON object.
    def self.parse?(token : String) : IDToken?
      segments = token.split('.')
      return unless segments.size == 3

      header_bytes = Base64URL.decode(segments[0])
      payload = Base64URL.decode(segments[1])
      signature = Base64URL.decode(segments[2])
      return unless header_bytes && payload && signature

      header = header_object(header_bytes)
      return unless header

      new(header["alg"]?.try(&.as_s?), header["kid"]?.try(&.as_s?), header.has_key?("crit"),
        "#{segments[0]}.#{segments[1]}".to_slice, signature, payload)
    end

    def inspect(io : IO) : Nil
      io << "Slack::OIDC::IDToken([REDACTED])"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    private def self.header_object(bytes : Bytes) : Hash(String, JSON::Any)?
      text = String.new(bytes)
      return unless text.valid_encoding?

      JSON.parse(text).as_h?
    rescue JSON::ParseException
      nil
    end
  end
end
