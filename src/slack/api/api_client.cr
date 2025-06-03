require "rate_limiter"

struct Slack::ApiClient
  class_getter limiters = {} of String => RateLimiter::LimiterLike

  @limiter : RateLimiter::LimiterLike
  @wait_time : Int32
  @http_client : HTTP::Client

  forward_missing_to @api

  def initialize(
    @api : Slack::Api::Base,
    limiter : RateLimiter::LimiterLike? = nil,
    wait_time : Int32? = nil,
  )
    limiter_id = "#{@api.token}:#{@api.class}"
    @@limiters[limiter_id] ||= limiter || tier_3_limiter
    @limiter = @@limiters[limiter_id]
    @wait_time = wait_time || 15
    @http_client = HTTP::Client.new("slack.com", port: 443, tls: true)
  end

  def post(body : String)
    @limiter.get!(@wait_time.seconds)
    @http_client.post(request_url, body: body, headers: headers)
  end

  def get(body : String)
    @limiter.get!(@wait_time.seconds)
    @http_client.get(request_url, body: body, headers: headers)
  end

  def get
    @limiter.get!(@wait_time.seconds)
    @http_client.get(request_url, headers: headers)
  end

  # Slack has *many* tiers of rate limits; tier 3 is ~50req/minute with
  # generous bursts. This is a good default.
  private def tier_3_limiter
    RateLimiter.new(rate: 0.8, max_burst: 20)
  end
end
