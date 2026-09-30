require "http"
require "random/secure"
require "uri"
require "../api"
require "../auth/api_configuration"
require "../auth/endpoint_validator"
require "../auth/state"
require "../oauth/response_error"
require "./configuration"
require "./id_token_verifier"
require "./key_source"
require "./sign_in"

module Slack::OIDC
  # Signs a person in with their Slack account through OpenID Connect.
  # See https://docs.slack.dev/authentication/sign-in-with-slack.
  #
  # `#redirect_url` issues state and a nonce bound to the trusted browser
  # session and returns Slack's authorization URL. `#authenticate_user`
  # consumes the state, exchanges the code through `openid.connect.token`,
  # verifies the ID token, and returns a `SignIn`. The application owns the
  # session: it gives the same trusted session binding to both calls.
  #
  # ```
  # handler = Slack::OIDC::SignInHandler.new(configuration, Slack::Auth::MemoryStateStore.new,
  #   Slack::Auth::HTTPTransportFactory.new.build(Slack::Auth::TransportOptions.new))
  # handler.redirect_url(session_binding)                         # send the browser here
  # sign_in = handler.authenticate_user(request, session_binding) # on the callback
  # sign_in.identity.user_id
  # ```
  class SignInHandler
    RESERVED_AUTHORIZATION_PARAMETERS = {"response_type", "client_id", "redirect_uri", "scope", "state", "nonce", "team"}

    # `openid.connect.token` errors that mean the person must sign in again.
    REAUTHORIZATION_ERRORS = {"invalid_code", "invalid_grant", "invalid_refresh_token", "token_revoked",
                              "token_expired", "access_denied"}
    # Other documented `openid.connect.token` errors that may reach diagnostics.
    RESPONSE_ERRORS = {"bad_client_secret", "invalid_client", "invalid_client_id", "bad_redirect_uri",
                       "oauth_authorization_url_mismatch", "invalid_grant_type", "unsupported_grant_type",
                       "ratelimited"}

    @authorization_uri : String
    @client_id : String
    @client_secret : Auth::Secret
    @redirect_uri : String
    @scope : String
    @state_store : Auth::StateStore
    @clock : Auth::Clock
    @state_ttl : Time::Span
    @client : Api::Client
    @verifier : IDTokenVerifier

    # The authorization request always asks for `openid`; *profile* and
    # *email* add those scopes. Raises `Auth::ContractError` with
    # `InvalidConfiguration` for a blank client ID or secret, a URI that is
    # not absolute HTTPS or that has user information or a fragment, an
    # authorization URI that sets a reserved parameter, or a *state_ttl* that
    # is not positive.
    def initialize(configuration : Configuration, state_store : Auth::StateStore, transport : Auth::Transport, *,
                   profile : Bool = true, email : Bool = true,
                   api_configuration : Auth::APIConfiguration = Auth::APIConfiguration.default,
                   signature_verifier : SignatureVerifier = OpenSSLVerifier.new,
                   clock : Auth::Clock = Auth::SystemClock.new, state_ttl : Time::Span = 10.minutes,
                   leeway : Time::Span = 60.seconds)
      validate_configuration(configuration, state_ttl)
      @authorization_uri = configuration.authorization_uri.to_s
      @client_id = configuration.client_id.dup
      @client_secret = Auth::Secret.new(configuration.client_secret.value.dup)
      @redirect_uri = configuration.redirect_uri.to_s
      @scope = scope(profile, email)
      @state_store = state_store
      @clock = clock
      @state_ttl = state_ttl
      # The exchange needs no token; the client adds no Authorization header.
      @client = Api::Client.new(token: nil, configuration: api_configuration, transport: transport)
      key_source = KeySource.new(URI.parse(configuration.jwks_uri.to_s), transport, clock: clock)
      @verifier = IDTokenVerifier.new(configuration, key_source,
        signature_verifier: signature_verifier, clock: clock, leeway: leeway)
    end

    # Issues a new attempt to the state store and returns the authorization
    # URL. *team* is Slack's workspace hint: a person already signed in to
    # that workspace goes through directly. It does not restrict the
    # workspace; compare `identity.team_id` for that.
    def redirect_url(session_binding : Auth::Secret, *, team : String? = nil) : String
      invalid_configuration! if team.try(&.blank?)

      state = Auth::Secret.new(Random::Secure.hex(32))
      nonce = Auth::Secret.new(Random::Secure.hex(32))
      @state_store.issue(Auth::AuthorizationAttempt.new(state, session_binding, Auth::AuthorizationPurpose::OIDC,
        @clock.now + @state_ttl, @redirect_uri, nonce))

      uri = URI.parse(@authorization_uri)
      params = URI::Params.parse(uri.query || "")
      params["response_type"] = "code"
      params["scope"] = @scope
      params["client_id"] = @client_id
      params["redirect_uri"] = @redirect_uri
      params["state"] = state.value
      params["nonce"] = nonce.value
      params["team"] = team if team
      uri.query = params.to_s
      uri.to_s
    end

    # Handles Slack's callback *request* for the trusted *session_binding*.
    #
    # Raises `Auth::ContractError` with `InvalidState` for unknown, expired, or
    # foreign state; `ReauthorizationRequired` when the person denied access;
    # `InvalidResponse` for a malformed callback; `VerificationFailed` for an
    # ID token that fails a check. Raises `Auth::ResponseError` when Slack
    # rejects the exchange. Transport errors pass through.
    def authenticate_user(request : HTTP::Request, session_binding : Auth::Secret) : SignIn
      params = request.query_params
      # Spend valid state before checking denial or code fields, even when they are invalid.
      attempt = consume_attempt(params, session_binding)
      code = authorization_code(params)
      token = request_token(Api::OpenIDConnectToken.new(client_id: @client_id, client_secret: @client_secret,
        code: code, redirect_uri: attempt.redirect_uri))
      id_token = token.id_token || raise Auth::ResponseError.new(Auth::ErrorCode::InvalidResponse)
      nonce = attempt.nonce || raise Auth::ContractError.new(Auth::ErrorCode::InvalidState)
      identity = @verifier.verify(id_token, nonce: nonce, access_token: token.access_token)
      SignIn.new(identity, user_token(token))
    end

    def inspect(io : IO) : Nil
      io << "Slack::OIDC::SignInHandler(client_id=" << @client_id << ')'
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    private def consume_attempt(params : URI::Params, session_binding : Auth::Secret) : Auth::AuthorizationAttempt
      state = exactly_one_nonblank(params, "state", Auth::ErrorCode::InvalidState)
      @state_store.consume(Auth::Secret.new(state), session_binding, Auth::AuthorizationPurpose::OIDC)
    end

    private def authorization_code(params : URI::Params) : String
      errors = params.fetch_all("error")
      unless errors.empty?
        raise Auth::ContractError.new(Auth::ErrorCode::InvalidResponse) if errors.size != 1 || errors.first.blank?
        raise Auth::ContractError.new(Auth::ErrorCode::ReauthorizationRequired)
      end

      exactly_one_nonblank(params, "code", Auth::ErrorCode::InvalidResponse)
    end

    # Maps Slack's error to the same allowlisted codes as the installation flow.
    private def request_token(request : Api::OpenIDConnectToken) : Models::OpenID::Token
      @client.call(request)
    rescue error : Api::Error
      slack_error = error.code
      code = case slack_error
             when .in?(REAUTHORIZATION_ERRORS) then Auth::ErrorCode::ReauthorizationRequired
             when .in?(RESPONSE_ERRORS)        then Auth::ErrorCode::InvalidResponse
             else
               slack_error = nil
               Auth::ErrorCode::InvalidResponse
             end
      raise Auth::ResponseError.new(code, error.http_status, error.retry_after, slack_error)
    end

    private def user_token(token : Models::OpenID::Token) : UserToken
      seconds = token.expires_in
      raise Auth::ResponseError.new(Auth::ErrorCode::InvalidResponse) if seconds && seconds <= 0

      UserToken.new(token.access_token, token.refresh_token, seconds.try { |value| @clock.now + value.seconds })
    end

    private def exactly_one_nonblank(params : URI::Params, name : String, error_code : Auth::ErrorCode) : String
      values = params.fetch_all(name)
      raise Auth::ContractError.new(error_code) unless values.size == 1
      value = values.first
      raise Auth::ContractError.new(error_code) if value.blank?
      value
    end

    private def scope(profile : Bool, email : Bool) : String
      scopes = ["openid"]
      scopes << "profile" if profile
      scopes << "email" if email
      scopes.join(' ')
    end

    private def validate_configuration(configuration : Configuration, state_ttl : Time::Span) : Nil
      invalid_configuration! if configuration.client_id.blank? || configuration.client_secret.value.blank?
      invalid_configuration! unless state_ttl > Time::Span.zero
      {configuration.authorization_uri, configuration.redirect_uri, configuration.jwks_uri}.each do |uri|
        Auth::EndpointValidator.validate!(uri)
        invalid_configuration! unless uri.scheme == "https"
      end

      URI::Params.parse(configuration.authorization_uri.query || "").each do |name, _value|
        invalid_configuration! if RESERVED_AUTHORIZATION_PARAMETERS.includes?(name)
      end
    end

    private def invalid_configuration! : NoReturn
      raise Auth::ContractError.new(Auth::ErrorCode::InvalidConfiguration)
    end
  end
end
