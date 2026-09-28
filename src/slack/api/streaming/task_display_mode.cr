# How Slack shows task updates in a streamed message.
# `Timeline` (Slack's default) shows each task as a card between text.
# `Plan` shows all tasks together in one plan block.
enum Slack::Api::Streaming::TaskDisplayMode
  Timeline
  Plan

  def wire_value : String
    case self
    in .timeline? then "timeline"
    in .plan?     then "plan"
    end
  end
end
