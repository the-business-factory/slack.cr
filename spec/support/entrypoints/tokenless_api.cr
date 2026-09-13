require "slack"

class ConsumerLimiter
  include RateLimiter::LimiterLike

  getter? waited : Bool = false

  def get : RateLimiter::Token
    @waited = true
    RateLimiter::Token.new
  end

  def get(max_wait : Time::Span) : RateLimiter::Token | RateLimiter::Timeout
    get
  end
end

class ConsumerScopedTransport < Slack::Auth::Transport
  getter credential_reads : Int32 = 0

  def initialize(@limiter : ConsumerLimiter)
  end

  def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
    raise "Credential read occurred before the limiter wait" unless @limiter.waited?
    raise "Endpoint supplied a bearer header" if request.headers["Authorization"]?

    @credential_reads += 1
    Slack::Auth::TransportResponse.new(
      200,
      HTTP::Headers.new,
      File.read("spec/fixtures/api/team-info-success.json")
    )
  end
end

Habitat.raise_if_missing_settings!
limiter = ConsumerLimiter.new
transport = ConsumerScopedTransport.new(limiter)
team = Slack::Api::TeamInfo.tokenless(transport: transport, limiter: limiter).call
raise "Unexpected API response" unless team.name == "goalsurfer"
raise "Unexpected credential read count" unless transport.credential_reads == 1
