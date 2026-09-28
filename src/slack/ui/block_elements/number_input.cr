# Slack sends number fields as strings. This type keeps them as strings, so
# decimal values do not change precision before they reach Slack.
struct Slack::UI::BlockElements::NumberInput
  include Slack::UI::ValueValidation

  private NUMBER = /\A(-?)([0-9]+)(?:\.([0-9]+))?\z/

  getter action_id : String?
  getter initial_value : String?
  getter min_value : String?
  getter max_value : String?
  getter dispatch_action_config : Slack::UI::CompositionObjects::DispatchActionConfig?
  getter focus_on_load : Bool?
  getter placeholder : Slack::UI::CompositionObjects::PlainText?

  def initialize(
    *,
    @is_decimal_allowed : Bool,
    @action_id : String? = nil,
    @initial_value : String? = nil,
    @min_value : String? = nil,
    @max_value : String? = nil,
    @dispatch_action_config : Slack::UI::CompositionObjects::DispatchActionConfig? = nil,
    @focus_on_load : Bool? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
  )
    validate!
  end

  def type : String
    "number_input"
  end

  # The `is_decimal_allowed` wire field.
  def decimal_allowed? : Bool
    @is_decimal_allowed
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "#{type}.placeholder.too_long", "placeholder.text")
    end
    if config = @dispatch_action_config
      config.validate.each { |issue| issues << issue.at("dispatch_action_config") }
    end
    initial_valid = number_issue(issues, @initial_value, "initial_value")
    minimum_valid = number_issue(issues, @min_value, "min_value")
    maximum_valid = number_issue(issues, @max_value, "max_value")
    # Slack documents only min <= max; an initial value outside the range is left to Slack.
    if minimum_valid && maximum_valid && (minimum = @min_value) && (maximum = @max_value) && compare(minimum, maximum) > 0
      issues << Slack::UI::ValidationIssue.new("#{type}.range.inverted", "min_value", "Minimum value cannot be greater than maximum value.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "is_decimal_allowed", @is_decimal_allowed
      json.field "action_id", @action_id if @action_id
      json.field "initial_value", @initial_value if @initial_value
      json.field "min_value", @min_value if @min_value
      json.field "max_value", @max_value if @max_value
      json.field "dispatch_action_config", @dispatch_action_config if @dispatch_action_config
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
      json.field "placeholder", @placeholder if @placeholder
    end
  end

  # Adds a format issue and returns false when a supplied value is not a usable number.
  private def number_issue(issues : Array(Slack::UI::ValidationIssue), value : String?, field : String) : Bool
    return true unless value
    match = NUMBER.match(value)
    unless match
      issues << Slack::UI::ValidationIssue.new("#{type}.#{field}.invalid", field, "Value must be a decimal number such as -10, 0 or 5.5.")
      return false
    end
    if match[3]? && !@is_decimal_allowed
      issues << Slack::UI::ValidationIssue.new("#{type}.#{field}.decimal_not_allowed", field, "Value must be a whole number when is_decimal_allowed is false.")
      return false
    end
    true
  end

  # Compares two values that match NUMBER without floating-point rounding.
  private def compare(left : String, right : String) : Int32
    left_negative, left_magnitude = decimal_parts(left)
    right_negative, right_magnitude = decimal_parts(right)
    return left_negative ? -1 : 1 unless left_negative == right_negative

    result = compare_magnitudes(left_magnitude, right_magnitude)
    left_negative ? -result : result
  end

  # Returns the sign and the digits without leading or trailing zeros. Zero is not negative.
  private def decimal_parts(value : String) : {Bool, {String, String}}
    match = NUMBER.match!(value)
    whole = match[2].lstrip('0')
    fraction = (match[3]? || "").rstrip('0')
    negative = match[1] == "-" && !(whole.empty? && fraction.empty?)
    {negative, {whole, fraction}}
  end

  private def compare_magnitudes(left : {String, String}, right : {String, String}) : Int32
    whole = left[0].size <=> right[0].size
    return whole unless whole.zero?
    width = {left[1].size, right[1].size}.max
    (left[0] + left[1].ljust(width, '0')) <=> (right[0] + right[1].ljust(width, '0'))
  end
end
