# Shared value checks for the checked input and modal contracts.
module Slack::UI::Checked::ValueValidation
  private def length_issue(issues : Array(ValidationIssue), value : String?, maximum : Int32, code : String, path : String) : Nil
    if value && value.size > maximum
      issues << ValidationIssue.new(code, path, "Value cannot be longer than #{maximum} characters.")
    end
  end

  def validate! : Nil
    issues = validate
    raise ValidationError.new(issues) unless issues.empty?
  end
end
