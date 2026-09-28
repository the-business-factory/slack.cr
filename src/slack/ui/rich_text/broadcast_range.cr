enum Slack::UI::RichText::BroadcastRange
  Here
  Channel
  Everyone

  def wire_value : String
    case self
    when .here?
      "here"
    when .channel?
      "channel"
    when .everyone?
      "everyone"
    else
      raise ValidationError.new([ValidationIssue.new("broadcast.range.invalid", "range", "Range must be here, channel, or everyone.")])
    end
  end
end
