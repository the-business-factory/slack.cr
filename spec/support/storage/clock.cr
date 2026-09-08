require "../../../src/slack/auth/clock"

module StorageSupport
  class Clock < Slack::Auth::Clock
    property now : Time = Time.utc(2026, 1, 1)
  end
end
