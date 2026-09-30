require "json"
require "../auth/errors"
require "./signing_key"

module Slack::OIDC
  # The usable RSA keys of one JSON Web Key Set document, by `kid`.
  struct KeySet
    @keys : Hash(String, SigningKey)

    def initialize(keys : Enumerable(SigningKey))
      @keys = {} of String => SigningKey
      keys.each { |key| @keys[key.kid] = key }
    end

    # Parses a `{"keys":[...]}` document and skips keys that cannot verify
    # RS256, such as EC keys. Raises `Auth::ContractError` with
    # `InvalidResponse` when the document has another shape, when it has no
    # usable key, or when two usable keys share a `kid`.
    def self.parse(json : String) : KeySet
      keys = parse_document(json)["keys"]?.try(&.as_a?) || invalid!
      usable = keys.compact_map { |jwk| SigningKey.from_jwk?(jwk) }
      invalid! if usable.empty? || usable.map(&.kid).uniq!.size != usable.size
      new(usable)
    end

    def []?(kid : String) : SigningKey?
      @keys[kid]?
    end

    def size : Int32
      @keys.size
    end

    private def self.parse_document(json : String) : Hash(String, JSON::Any)
      JSON.parse(json).as_h? || invalid!
    rescue JSON::ParseException
      invalid!
    end

    private def self.invalid! : NoReturn
      raise Auth::ContractError.new(Auth::ErrorCode::InvalidResponse)
    end
  end
end
