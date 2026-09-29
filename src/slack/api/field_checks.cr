require "../ui/validation_issue"

# :nodoc:
# Field checks shared by Web API requests. Each issue code is
# `<prefix>.<path>.<reason>`, where *prefix* names the request.
module Slack::Api::FieldChecks
  # Slack ts values contain epoch seconds and a fraction. Check only their
  # shape: fixed digit counts are not documented, and Float loses precision.
  # https://docs.slack.dev/changelog/2016/05/31/more-events-timestamps-in-rtm-api/
  def self.timestamp?(value : String) : Bool
    /\A[0-9]+\.[0-9]+\z/.matches?(value)
  end

  # Adds a `blank` issue when *value* is present and blank.
  def self.blank_issue(issues : Array(Slack::UI::ValidationIssue), prefix : String, path : String,
                       value : String?, label : String) : Nil
    return unless value.try(&.blank?)

    issues << Slack::UI::ValidationIssue.new("#{prefix}.#{path}.blank", path, "#{label} must not be blank.")
  end

  # Adds an `invalid` issue when *value* is present and is not a Slack timestamp.
  def self.timestamp_issue(issues : Array(Slack::UI::ValidationIssue), prefix : String, path : String,
                           value : String?, label : String = "Timestamp") : Nil
    return if value.nil? || timestamp?(value)

    issues << Slack::UI::ValidationIssue.new("#{prefix}.#{path}.invalid", path,
      "#{label} must contain digits, a decimal point, and fractional digits.")
  end
end
