require "crypto/subtle"
require "digest/sha256"
require "../auth/clock"
require "../auth/errors"
require "./base64_url"
require "./claims"
require "./configuration"
require "./id_token"
require "./identity"
require "./key_source"
require "./openssl_verifier"

module Slack::OIDC
  # Verifies a Slack ID token and returns its `Identity`
  # (OpenID Connect Core 1.0, sections 3.1.3.7 and 3.1.3.8).
  #
  # The header selects the key, the signature is checked, and only then is
  # the payload parsed and every claim checked. Any failed check raises
  # `Auth::ContractError` with `VerificationFailed`, which contains no claim
  # and no token text. Key set fetch errors come from `KeySource#key`.
  class IDTokenVerifier
    ALGORITHM = "RS256"

    @client_id : String
    @issuer : String

    # Raises `Auth::ContractError` with `InvalidConfiguration` for a blank
    # client ID or issuer, or a negative *leeway*.
    def initialize(configuration : Configuration, @key_source : KeySource, *,
                   @signature_verifier : SignatureVerifier = OpenSSLVerifier.new,
                   @clock : Auth::Clock = Auth::SystemClock.new, @leeway : Time::Span = 60.seconds)
      if configuration.client_id.blank? || configuration.issuer.blank? || @leeway < Time::Span.zero
        raise Auth::ContractError.new(Auth::ErrorCode::InvalidConfiguration)
      end
      @client_id = configuration.client_id.dup
      @issuer = configuration.issuer.dup
    end

    # *nonce* is the value sent in the authorization request. *access_token*
    # is the token returned with the ID token; `at_hash` must match it.
    def verify(id_token : Auth::Secret, *, nonce : Auth::Secret, access_token : Auth::Secret) : Identity
      token = IDToken.parse?(id_token.value) || failed!
      kid = token.kid.presence
      failed! if token.algorithm != ALGORITHM || kid.nil? || token.critical?

      key = @key_source.key(kid) || failed!
      failed! unless @signature_verifier.verify(key, token.signing_input, token.signature)

      # The payload is parsed only now, after the signature verified.
      claims = Claims.parse?(token.payload) || failed!
      check_issuer_and_audience(claims)
      expires_at = check_times(claims)
      failed! unless equal?(claims.nonce, nonce.value)
      failed! unless equal?(claims.at_hash, at_hash(access_token))
      identity(claims, expires_at)
    end

    def inspect(io : IO) : Nil
      io << "Slack::OIDC::IDTokenVerifier(client_id=" << @client_id << ')'
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    private def check_issuer_and_audience(claims : Claims) : Nil
      failed! unless claims.iss == @issuer

      case audience = claims.aud
      in String
        failed! unless audience == @client_id
      in Array(String)
        failed! unless audience.includes?(@client_id)
        # A token for several audiences names its authorized party.
        failed! if audience.size > 1 && claims.azp.nil?
      in Nil
        failed!
      end
      azp = claims.azp
      failed! if azp && azp != @client_id
    end

    # Returns the expiry. Both times allow *leeway* for clock skew.
    private def check_times(claims : Claims) : Time
      expires_at = time(claims.exp) || failed!
      issued_at = time(claims.iat) || failed!
      now = @clock.now
      failed! unless now < expires_at + @leeway
      failed! unless issued_at <= now + @leeway
      expires_at
    end

    private def identity(claims : Claims, expires_at : Time) : Identity
      subject = required(claims.sub)
      user_id = required(claims.user_id)
      team_id = required(claims.team_id)
      authenticated_at = claims.auth_time.try { |seconds| time(seconds) }
      Identity.new(subject, user_id, team_id, expires_at,
        email: claims.email, email_verified: claims.email_verified, name: claims.name,
        given_name: claims.given_name, family_name: claims.family_name, locale: claims.locale,
        authenticated_at: authenticated_at)
    end

    # at_hash is the base64url of the left half of the SHA-256 of the access
    # token (OpenID Connect Core 1.0, section 3.1.3.6).
    private def at_hash(access_token : Auth::Secret) : String
      digest = Digest::SHA256.digest(access_token.value)
      Base64URL.encode(digest[0, digest.size // 2])
    end

    private def equal?(claim : String?, expected : String) : Bool
      return false unless claim

      Crypto::Subtle.constant_time_compare(claim, expected)
    end

    # Unix seconds up to the year 9999; other values are not a valid time.
    private def time(seconds : Int64?) : Time?
      return unless seconds && 0 <= seconds <= 253_402_300_799

      Time.unix(seconds)
    end

    private def required(value : String?) : String
      value.presence || failed!
    end

    private def failed! : NoReturn
      raise Auth::ContractError.new(Auth::ErrorCode::VerificationFailed)
    end
  end
end
