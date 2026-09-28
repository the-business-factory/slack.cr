# An emoji icon, for example `":robot_face:"`.
struct Slack::UI::Icon::Emoji
  include Slack::UI::Icon
  include Slack::UI::ValueValidation

  getter value : String

  def initialize(@value : String)
    validate!
  end

  def wire_field : String
    "icon_emoji"
  end

  def validate : Array(ValidationIssue)
    return [] of ValidationIssue unless @value.blank?

    [ValidationIssue.new("icon.emoji.blank", "icon_emoji", "Icon emoji must not be blank.")]
  end
end
