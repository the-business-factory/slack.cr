record Slack::UI::Checked::ValidationIssue,
  code : String,
  path : String,
  message : String do
  def at(prefix : String) : ValidationIssue
    nested_path = @path.empty? ? prefix : "#{prefix}.#{@path}"
    ValidationIssue.new(code: @code, path: nested_path, message: @message)
  end
end
