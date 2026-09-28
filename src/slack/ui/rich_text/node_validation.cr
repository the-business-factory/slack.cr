# :nodoc:
# Shared checks for rich text nodes. Nonempty values and children are library policy.
module Slack::UI::Checked::RichText::NodeValidation
  include Slack::UI::Checked::ValueValidation

  private def empty_issue(issues : Array(ValidationIssue), value : String, code : String, path : String) : Nil
    issues << ValidationIssue.new(code, path, "Value must not be empty.") if value.empty?
  end

  private def children_issues(issues : Array(ValidationIssue), children : Array(T), code : String) : Nil forall T
    if children.empty?
      issues << ValidationIssue.new(code, "elements", "Elements must contain at least one element.")
    end
    children.each_with_index do |child, index|
      child.validate.each { |issue| issues << issue.at("elements[#{index}]") }
    end
  end

  private def border_issue(issues : Array(ValidationIssue), border : Int32?, code : String) : Nil
    return if border.nil? || border.in?(0, 1)

    issues << ValidationIssue.new(code, "border", "Border must be 0 or 1.")
  end
end
