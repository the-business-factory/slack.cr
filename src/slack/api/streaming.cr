# :nodoc:
# Checks shared by the streaming requests.
module Slack::Api::Streaming
  def self.stream_issues(prefix : String, channel : String, ts : String) : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    FieldChecks.blank_issue(issues, prefix, "channel", channel, "Channel")
    FieldChecks.timestamp_issue(issues, prefix, "ts", ts, "Message timestamp")
    issues
  end
end
