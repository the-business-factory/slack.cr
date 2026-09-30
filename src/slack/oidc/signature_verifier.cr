require "./signing_key"

module Slack::OIDC
  # Checks one RS256 signature. `IDTokenVerifier` selects the key and checks
  # the header and every claim itself; an implementation only answers whether
  # *signature* is a valid RSASSA-PKCS1-v1_5 SHA-256 signature of
  # *signing_input* under *key*.
  #
  # The default is `OpenSSLVerifier`. Implement this class to verify through
  # another library, such as a Crystal JWT shard.
  abstract class SignatureVerifier
    # Returns true only for a valid signature. Returns false for every other
    # input, including a malformed key or signature; does not raise for them.
    abstract def verify(key : SigningKey, signing_input : Bytes, signature : Bytes) : Bool
  end
end
