abstract struct Slack::UI::BlockElement
  include Slack::UI::DynamicTextComposition

  abstract def type
end
