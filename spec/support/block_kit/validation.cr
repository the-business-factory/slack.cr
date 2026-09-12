module Slack::UI::Checked
  record ValidationIssue,
    code : String,
    path : String,
    message : String

  class ValidationError < Exception
    getter issues : Array(ValidationIssue)

    def initialize(@issues : Array(ValidationIssue))
      super(@issues.map { |issue| "#{issue.path}: #{issue.message}" }.join("; "))
    end
  end
end
