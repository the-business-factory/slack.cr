# :nodoc:
# Field checks shared by the chat requests. Issue codes start with the request prefix.
module Slack::Api::ChatChecks
  def self.broadcast_issue(issues : Array(Slack::UI::ValidationIssue), prefix : String,
                           reply_broadcast : Bool?, thread_ts : String?) : Nil
    return unless reply_broadcast && thread_ts.nil?

    issues << Slack::UI::ValidationIssue.new("#{prefix}.reply_broadcast.thread_required", "reply_broadcast",
      "Reply broadcast requires a thread timestamp.")
  end
end
