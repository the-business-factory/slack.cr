# The color of an attachment's left border: a Slack named color or a hex code.
struct Slack::UI::Attachment::Color
  include Slack::UI::ValueValidation

  getter wire_value : String

  def self.good : Color
    new("good")
  end

  def self.warning : Color
    new("warning")
  end

  def self.danger : Color
    new("danger")
  end

  # Accepts `#RRGGBB`, for example `"#439FE0"`.
  def self.hex(value : String) : Color
    new(value)
  end

  private def initialize(@wire_value : String)
    validate!
  end

  def validate : Array(ValidationIssue)
    return [] of ValidationIssue if {"good", "warning", "danger"}.includes?(@wire_value)
    return [] of ValidationIssue if /\A#[0-9A-Fa-f]{6}\z/.matches?(@wire_value)

    [ValidationIssue.new("attachment.color.invalid_hex", "",
      "Attachment color must be good, warning, danger, or a #RRGGBB hex code.")]
  end
end
