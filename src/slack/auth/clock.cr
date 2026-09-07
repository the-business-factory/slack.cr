module Slack::Auth
  abstract class Clock
    abstract def now : Time
  end

  class SystemClock < Clock
    def now : Time
      Time.utc
    end
  end
end
