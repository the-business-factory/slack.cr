# :nodoc:
# Checks shared by the streaming requests.
module Slack::Api::Streaming
  # Slack ts values contain epoch seconds and a fraction. Check only their shape.
  def self.timestamp?(value : String) : Bool
    /\A[0-9]+\.[0-9]+\z/.matches?(value)
  end

  def self.stream_issues(prefix : String, channel : String, ts : String) : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if channel.blank?
      issues << Slack::UI::ValidationIssue.new("#{prefix}.channel.blank", "channel", "Channel must not be blank.")
    end
    unless timestamp?(ts)
      issues << Slack::UI::ValidationIssue.new("#{prefix}.ts.invalid", "ts",
        "Message timestamp must contain digits, a decimal point, and fractional digits.")
    end
    issues
  end
end
