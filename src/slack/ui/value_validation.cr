# Shared validation for Block Kit values. An including type defines
# `validate`; `validate!` raises its issues.
module Slack::UI::ValueValidation
  # Adds an issue when *value* is longer than *maximum*. The message names the
  # value as *subject*.
  private def length_issue(issues : Array(ValidationIssue), value : String?, maximum : Int32, code : String, path : String,
                           subject : String = "Value") : Nil
    if value && value.size > maximum
      issues << ValidationIssue.new(code, path, "#{subject} cannot be longer than #{maximum} characters.")
    end
  end

  def validate! : Nil
    issues = validate
    raise ValidationError.new(issues) unless issues.empty?
  end
end
