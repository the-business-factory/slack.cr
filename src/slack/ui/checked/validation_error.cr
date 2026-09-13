class Slack::UI::Checked::ValidationError < Slack::Errors::InvalidUIBlock
  @issues : Array(ValidationIssue)

  def initialize(issues : Array(ValidationIssue))
    @issues = issues.dup
    super(@issues.map { |issue| "#{issue.path}: #{issue.message}" }.join("; "))
  end

  def issues : Array(ValidationIssue)
    @issues.dup
  end
end
