require "http"
require "../auth/clock"
require "../auth/endpoint_validator"
require "../auth/transport"
require "./key_set"

module Slack::OIDC
  # Fetches and caches the JSON Web Key Set through an `Auth::Transport`.
  #
  # The cache is kept for *ttl*; `Cache-Control` is not read. A `kid` that
  # is not in the cache causes one more fetch, but at most once in each
  # *refresh_interval*, so tokens with random `kid` values cannot make the
  # application fetch on every request. No background fiber runs: fetches
  # happen inside `#key`.
  #
  # One mutex covers the lookup and the fetch, so concurrent callers wait for
  # a fetch in progress instead of fetching again.
  class KeySource
    @jwks_uri : String
    @transport : Auth::Transport
    @clock : Auth::Clock
    @ttl : Time::Span
    @refresh_interval : Time::Span
    @key_set : KeySet? = nil
    @fetched_at : Time? = nil
    @mutex = Mutex.new

    # Raises `Auth::ContractError` with `InvalidConfiguration` unless
    # *jwks_uri* is an absolute HTTPS URI and both spans are positive.
    def initialize(jwks_uri : URI, @transport : Auth::Transport, *, @clock : Auth::Clock = Auth::SystemClock.new,
                   @ttl : Time::Span = 24.hours, @refresh_interval : Time::Span = 5.minutes)
      Auth::EndpointValidator.validate!(jwks_uri)
      invalid_configuration! unless jwks_uri.scheme == "https"
      invalid_configuration! unless @ttl > Time::Span.zero && @refresh_interval > Time::Span.zero
      @jwks_uri = jwks_uri.to_s
    end

    # Returns the key for *kid*, or nil when a fresh key set does not have it.
    #
    # A failed fetch raises: `Auth::ContractError` with `InvalidResponse` for
    # a status other than 2xx or a document that is not a usable key set, and
    # the transport's error unchanged. A failed fetch also drops the cached
    # key set, so the next call fetches again instead of using keys that
    # could not be refreshed.
    def key(kid : String) : SigningKey?
      @mutex.synchronize do
        now = @clock.now
        cached = @key_set
        fetched_at = @fetched_at
        if cached.nil? || fetched_at.nil? || now - fetched_at >= @ttl
          return fetch(now)[kid]?
        end

        key = cached[kid]?
        return key if key
        return if now - fetched_at < @refresh_interval

        fetch(now)[kid]?
      end
    end

    def inspect(io : IO) : Nil
      io << "Slack::OIDC::KeySource(" << @jwks_uri << ')'
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    private def fetch(now : Time) : KeySet
      key_set = fetch_key_set
      @key_set = key_set
      @fetched_at = now
      key_set
    rescue error
      @key_set = nil
      @fetched_at = nil
      raise error
    end

    private def fetch_key_set : KeySet
      response = @transport.execute(Auth::TransportRequest.new(
        "GET", URI.parse(@jwks_uri), HTTP::Headers{"Accept" => "application/json"}))
      unless (200..299).includes?(response.status)
        raise Auth::ContractError.new(Auth::ErrorCode::InvalidResponse, response.status)
      end

      KeySet.parse(response.body)
    end

    private def invalid_configuration! : NoReturn
      raise Auth::ContractError.new(Auth::ErrorCode::InvalidConfiguration)
    end
  end
end
