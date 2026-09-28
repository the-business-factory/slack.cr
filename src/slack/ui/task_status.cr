# The status of one task in a streamed task update or a task card.
#
# Slack documents `in_progress`, `complete`, and `error`. `Pending` comes from
# the Slack Python SDK (`TaskUpdateChunk`) and is not on the Slack reference page.
enum Slack::UI::TaskStatus
  Pending
  InProgress
  Complete
  Error

  def wire_value : String
    case self
    in .pending?     then "pending"
    in .in_progress? then "in_progress"
    in .complete?    then "complete"
    in .error?       then "error"
    end
  end
end
