require "./lib_crypto"
require "./rsa_public_key_der"
require "./signature_verifier"

module Slack::OIDC
  # Verifies RS256 signatures with the OpenSSL library that Crystal links.
  class OpenSSLVerifier < SignatureVerifier
    def verify(key : SigningKey, signing_input : Bytes, signature : Bytes) : Bool
      der = RSAPublicKeyDER.encode(key.modulus, key.exponent)
      # d2i_PUBKEY moves the pointer it gets, so it gets a copy.
      cursor = der.to_unsafe
      public_key = ::LibCrypto.d2i_pubkey(nil, pointerof(cursor), der.size)
      return false if public_key.null?

      begin
        verify_with(public_key, signing_input, signature)
      ensure
        ::LibCrypto.evp_pkey_free(public_key)
      end
    ensure
      # A failed check leaves OpenSSL errors in the thread's queue, where a
      # later TLS call could read them.
      ::LibCrypto.err_clear_error
    end

    private def verify_with(public_key : Void*, signing_input : Bytes, signature : Bytes) : Bool
      context = ::LibCrypto.evp_md_ctx_new
      return false if context.null?

      begin
        return false unless ::LibCrypto.evp_digestverifyinit(context, nil, ::LibCrypto.evp_sha256, nil, public_key) == 1

        # Only 1 means a valid signature; 0 and negative values are failures.
        ::LibCrypto.evp_digestverify(context, signature, signature.size, signing_input, signing_input.size) == 1
      ensure
        ::LibCrypto.evp_md_ctx_free(context)
      end
    end
  end
end
