require "../../../src/slack/auth/clock"

module StorageSupport
  class FileClock < Slack::Auth::Clock
    def initialize(@path : String)
    end

    def now : Time
      Time.unix(File.read(@path).to_i64)
    end
  end
end
