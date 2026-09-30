require "openssl"

# :nodoc:
# OpenSSL 3 EVP functions for RS256 verification, added to the standard
# library's `LibCrypto`, which `require "openssl"` links. C function names are
# global, so these reuse the standard library's `EVP_sha256`, `EVP_MD_CTX_new`,
# and `EVP_MD_CTX_free` and its types. Prototypes are from the OpenSSL 3 headers.
lib LibCrypto
  fun d2i_pubkey = d2i_PUBKEY(a : Void**, pp : UInt8**, length : LibC::Long) : Void*
  fun evp_pkey_free = EVP_PKEY_free(pkey : Void*)
  fun evp_digestverifyinit = EVP_DigestVerifyInit(ctx : EVP_MD_CTX, pctx : Void**, type : EVP_MD, e : Void*, pkey : Void*) : LibC::Int
  fun evp_digestverify = EVP_DigestVerify(ctx : EVP_MD_CTX, sig : UInt8*, siglen : LibC::SizeT, tbs : UInt8*, tbslen : LibC::SizeT) : LibC::Int
  fun err_clear_error = ERR_clear_error
end
