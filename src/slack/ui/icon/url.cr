# An image URL icon.
struct Slack::UI::Icon::Url
  include Slack::UI::Icon
  include Slack::UI::ValueValidation

  getter value : String

  def initialize(@value : String)
    validate!
  end

  def wire_field : String
    "icon_url"
  end

  def validate : Array(ValidationIssue)
    return [] of ValidationIssue unless @value.blank?

    [ValidationIssue.new("icon.url.blank", "icon_url", "Icon URL must not be blank.")]
  end
end
