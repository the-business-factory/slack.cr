# :nodoc:
# Field checks shared by the chat requests. Issue codes start with the request prefix.
module Slack::Api::ChatChecks
  # Slack ts values contain epoch seconds and a fraction. Check only their
  # shape: fixed digit counts are not documented, and Float loses precision.
  # https://docs.slack.dev/changelog/2016/05/31/more-events-timestamps-in-rtm-api/
  def self.timestamp?(value : String) : Bool
    /\A[0-9]+\.[0-9]+\z/.matches?(value)
  end

  def self.blank_issue(issues : Array(Slack::UI::ValidationIssue), prefix : String, path : String,
                       value : String?, label : String) : Nil
    return unless value.try(&.blank?)

    issues << Slack::UI::ValidationIssue.new("#{prefix}.#{path}.blank", path, "#{label} must not be blank.")
  end

  def self.timestamp_issue(issues : Array(Slack::UI::ValidationIssue), prefix : String, path : String,
                           value : String?) : Nil
    return if value.nil? || timestamp?(value)

    issues << Slack::UI::ValidationIssue.new("#{prefix}.#{path}.invalid", path,
      "Timestamp must contain digits, a decimal point, and fractional digits.")
  end

  def self.broadcast_issue(issues : Array(Slack::UI::ValidationIssue), prefix : String,
                           reply_broadcast : Bool?, thread_ts : String?) : Nil
    return unless reply_broadcast && thread_ts.nil?

    issues << Slack::UI::ValidationIssue.new("#{prefix}.reply_broadcast.thread_required", "reply_broadcast",
      "Reply broadcast requires a thread timestamp.")
  end
end
