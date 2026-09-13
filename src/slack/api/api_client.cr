require "rate_limiter"
require "../auth/http_transport_factory"

struct Slack::ApiClient
  class_getter limiters = {} of String => RateLimiter::LimiterLike

  @limiter : RateLimiter::LimiterLike
  @wait_time : Int32
  @transport : Slack::Auth::Transport

  forward_missing_to @api

  def initialize(
    @api : Slack::Api::Base,
    limiter : RateLimiter::LimiterLike? = nil,
    wait_time : Int32? = nil,
    transport : Slack::Auth::Transport? = nil,
  )
    token = @api.token
    raise ArgumentError.new("API token must not be blank") if token.try(&.blank?)

    @limiter = limiter || default_limiter(token)
    @wait_time = wait_time || 15
    @transport = transport || default_transport(token)
  end

  def post(body : String) : HTTP::Client::Response
    execute("POST", body)
  end

  def get(body : String) : HTTP::Client::Response
    execute("GET", body)
  end

  def get : HTTP::Client::Response
    execute("GET")
  end

  private def execute(method : String, body : String? = nil) : HTTP::Client::Response
    @limiter.get!(@wait_time.seconds)
    response = @transport.execute(Slack::Auth::TransportRequest.new(
      method,
      URI.parse(request_url),
      headers,
      body
    ))
    status = HTTP::Status.new(response.status)
    response_body = HTTP::Client::Response.mandatory_body?(status) ? response.body : nil
    HTTP::Client::Response.new(status, body: response_body, headers: response.headers)
  end

  # Slack has *many* tiers of rate limits; tier 3 is ~50req/minute with
  # generous bursts. This is a good default.
  private def tier_3_limiter : RateLimiter::LimiterLike
    RateLimiter.new(rate: 0.8, max_burst: 20)
  end

  private def default_limiter(token : String?) : RateLimiter::LimiterLike
    unless token
      raise ArgumentError.new("Tokenless API endpoints require an explicit limiter")
    end

    limiter_id = "#{token}:#{@api.class}"
    @@limiters[limiter_id] ||= tier_3_limiter
  end

  private def default_transport(token : String?) : Slack::Auth::Transport
    unless token
      raise ArgumentError.new("Tokenless API endpoints require an explicit transport")
    end

    Slack::Auth::HTTPTransportFactory.new.build(Slack.settings.api_transport_options)
  end
end
