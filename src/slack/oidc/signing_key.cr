require "json"
require "./base64_url"

module Slack::OIDC
  # One RSA public key from Slack's JSON Web Key Set, selected by `kid`.
  struct SigningKey
    # RFC 7518 section 3.3: RS256 keys have at least 2048 bits.
    MINIMUM_MODULUS_BITS = 2048

    getter kid : String
    getter modulus : Bytes
    getter exponent : Bytes

    def initialize(@kid : String, @modulus : Bytes, @exponent : Bytes)
    end

    # Returns nil for a key that cannot verify RS256: another key type, a
    # blank `kid`, `use` other than `sig`, `alg` other than `RS256`, a missing
    # or malformed `n` or `e`, or a modulus under 2048 bits.
    def self.from_jwk?(jwk : JSON::Any) : SigningKey?
      fields = jwk.as_h?
      return unless fields && string(fields, "kty") == "RSA"
      return unless optional_member?(fields, "use", "sig") && optional_member?(fields, "alg", "RS256")

      kid = string(fields, "kid").presence
      modulus = string(fields, "n").try { |text| Base64URL.decode(text) }
      exponent = string(fields, "e").try { |text| Base64URL.decode(text) }
      return if kid.nil? || modulus.nil? || exponent.nil? || exponent.empty?
      return unless significant_bits(modulus) >= MINIMUM_MODULUS_BITS

      new(kid, modulus, exponent)
    end

    def inspect(io : IO) : Nil
      io << "Slack::OIDC::SigningKey(kid=" << @kid.inspect << ')'
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    private def self.string(fields : Hash(String, JSON::Any), name : String) : String?
      fields[name]?.try(&.as_s?)
    end

    private def self.optional_member?(fields : Hash(String, JSON::Any), name : String, expected : String) : Bool
      value = fields[name]?
      value.nil? || value.as_s? == expected
    end

    private def self.significant_bits(value : Bytes) : Int32
      index = value.index { |byte| byte != 0 }
      return 0 unless index

      (value.size - index - 1) * 8 + (8 - value[index].leading_zeros_count)
    end
  end
end
