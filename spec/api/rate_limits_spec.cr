require "../spec_helper"

private class ManualClock < Slack::Auth::Clock
  property now : Time = Time.utc(2026, 9, 28)

  def advance(span : Time::Span) : Nil
    @now += span
  end
end

private def recording_limits(clock : ManualClock, waits : Array(Time::Span)) : Slack::Api::RateLimits
  Slack::Api::RateLimits.new(clock, ->(span : Time::Span) { waits << span; nil })
end

describe Slack::Api::RateLimits do
  it "waits for the Tier 1 window before a second call to the same method" do
    clock = ManualClock.new
    waits = [] of Time::Span
    limits = recording_limits(clock, waits)

    limits.wait("apps.manifest.update", Slack::Api::RateLimitTier::Tier1)
    waits.should be_empty
    clock.advance(15.seconds)
    limits.wait("apps.manifest.update", Slack::Api::RateLimitTier::Tier1)

    waits.should eq [45.seconds]
  end

  it "paces each method separately" do
    clock = ManualClock.new
    waits = [] of Time::Span
    limits = recording_limits(clock, waits)

    limits.wait("apps.manifest.update", Slack::Api::RateLimitTier::Tier1)
    limits.wait("auth.test", Slack::Api::RateLimitTier::Tier1)

    waits.should be_empty
  end

  it "allows the tier burst, then spaces calls at the tier rate" do
    clock = ManualClock.new
    waits = [] of Time::Span
    limits = recording_limits(clock, waits)
    tier = Slack::Api::RateLimitTier::Tier4

    tier.burst.times { limits.wait("views.open", tier) }
    waits.should be_empty
    2.times { limits.wait("views.open", tier) }

    waits.should eq [0.6.seconds, 1.2.seconds]
  end

  it "refills no more than the burst after an idle period" do
    clock = ManualClock.new
    waits = [] of Time::Span
    limits = recording_limits(clock, waits)
    tier = Slack::Api::RateLimitTier::Tier2

    limits.wait("users.list", tier)
    clock.advance(1.hour)
    (tier.burst + 1).times { limits.wait("users.list", tier) }

    waits.should eq [3.seconds]
  end
end

describe Slack::Api::RateLimitTier do
  it "uses the documented minimum per-minute rate for each numbered tier" do
    # https://docs.slack.dev/apis/web-api/rate-limits
    Slack::Api::RateLimitTier::Tier1.per_minute.should eq 1
    Slack::Api::RateLimitTier::Tier2.per_minute.should eq 20
    Slack::Api::RateLimitTier::Tier3.per_minute.should eq 50
    Slack::Api::RateLimitTier::Tier4.per_minute.should eq 100
  end
end
