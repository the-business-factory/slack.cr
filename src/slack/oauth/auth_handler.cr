require "random/secure"
require "../auth/storage/memory_state_store"
require "./auth_response"

# Issues and consumes session-bound state for Slack app installation OAuth.
class Slack::AuthHandler
  RESERVED_AUTHORIZATION_PARAMETERS = {"client_id", "redirect_uri", "scope", "state", "user_scope"}

  @authorization_uri : URI
  @token_uri : URI
  @client_id : String
  @client_secret : Auth::Secret
  @redirect_uri : String
  @state_store : Auth::StateStore
  @transport : Auth::Transport
  @bot_scopes : Array(String)
  @user_scopes : Array(String)
  @clock : Auth::Clock
  @state_ttl : Time::Span

  def initialize(configuration : Auth::OAuthConfiguration, state_store : Auth::StateStore,
                 transport : Auth::Transport, *, bot_scopes : Array(String) = [] of String,
                 user_scopes : Array(String) = [] of String,
                 clock : Auth::Clock = Auth::SystemClock.new,
                 state_ttl : Time::Span = 10.minutes)
    validate_configuration(configuration, state_ttl)
    @authorization_uri = snapshot_uri(configuration.authorization_uri)
    @token_uri = snapshot_uri(configuration.token_uri)
    @client_id = configuration.client_id.dup
    @client_secret = Auth::Secret.new(configuration.client_secret.value.dup)
    @redirect_uri = snapshot_uri(configuration.redirect_uri).to_s
    @state_store = state_store
    @transport = transport
    @bot_scopes = bot_scopes.dup
    @user_scopes = user_scopes.dup
    @clock = clock
    @state_ttl = state_ttl
  end

  def redirect_url(session_binding : Auth::Secret) : String
    state = Auth::Secret.new(Random::Secure.hex(32))
    attempt = Auth::AuthorizationAttempt.new(
      state,
      session_binding,
      Auth::AuthorizationPurpose::Installation,
      @clock.now + @state_ttl,
      @redirect_uri
    )
    @state_store.issue(attempt)

    uri = snapshot_uri(@authorization_uri)
    params = URI::Params.parse(uri.query || "")
    params["client_id"] = @client_id
    params["redirect_uri"] = @redirect_uri
    params["scope"] = @bot_scopes.join(',')
    params["state"] = state.value
    params["user_scope"] = @user_scopes.join(',')
    uri.query = params.to_s
    uri.to_s
  end

  def authenticate_user(request : HTTP::Request, session_binding : Auth::Secret) : Slack::AuthResponse
    state = exactly_one_nonblank(request.query_params, "state", Auth::ErrorCode::InvalidState)
    attempt = @state_store.consume(Auth::Secret.new(state), session_binding,
      Auth::AuthorizationPurpose::Installation)

    errors = request.query_params.fetch_all("error")
    unless errors.empty?
      raise Auth::ContractError.new(Auth::ErrorCode::InvalidResponse) if errors.size != 1 || errors.first.blank?
      raise Auth::ContractError.new(Auth::ErrorCode::ReauthorizationRequired)
    end

    code = exactly_one_nonblank(request.query_params, "code", Auth::ErrorCode::InvalidResponse)
    response = @transport.execute(Auth::TransportRequest.new(
      "POST",
      snapshot_uri(@token_uri),
      HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      URI::Params.encode({
        "client_id"     => @client_id,
        "client_secret" => @client_secret.value,
        "code"          => code,
        "redirect_uri"  => attempt.redirect_uri,
      })
    ))
    Slack::AuthResponse.parse(response)
  end

  private def exactly_one_nonblank(params : URI::Params, name : String,
                                   error_code : Auth::ErrorCode) : String
    values = params.fetch_all(name)
    raise Auth::ContractError.new(error_code) unless values.size == 1
    value = values.first
    raise Auth::ContractError.new(error_code) if value.blank?
    value
  end

  private def validate_configuration(configuration : Auth::OAuthConfiguration,
                                     state_ttl : Time::Span) : Nil
    invalid_configuration! if configuration.client_id.blank? || configuration.client_secret.value.blank?
    invalid_configuration! unless state_ttl > Time::Span.zero

    validate_https_uri(configuration.authorization_uri)
    validate_https_uri(configuration.token_uri)
    validate_https_uri(configuration.redirect_uri)

    params = URI::Params.parse(configuration.authorization_uri.query || "")
    params.each do |name, _value|
      invalid_configuration! if RESERVED_AUTHORIZATION_PARAMETERS.includes?(name)
    end
  end

  private def validate_https_uri(uri : URI) : Nil
    invalid_configuration! if uri.scheme != "https" || uri.host.to_s.blank?
    invalid_configuration! unless uri.user.nil? && uri.password.nil? && uri.fragment.nil?
  end

  private def invalid_configuration! : NoReturn
    raise Auth::ContractError.new(Auth::ErrorCode::InvalidConfiguration)
  end

  private def snapshot_uri(uri : URI) : URI
    URI.parse(uri.to_s)
  end
end
