enum Slack::UI::RichText::ListStyle
  Bullet
  Ordered

  def wire_value : String
    case self
    when .bullet?
      "bullet"
    when .ordered?
      "ordered"
    else
      raise ValidationError.new([ValidationIssue.new("rich_text_list.style.invalid", "style", "Style must be bullet or ordered.")])
    end
  end
end
