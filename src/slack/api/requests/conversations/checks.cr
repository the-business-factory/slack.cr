# :nodoc:
# Field checks shared by the conversations write requests. Issue codes start
# with the request prefix.
module Slack::Api::ConversationChecks
  # conversations.create and conversations.rename: names have at most 80 characters.
  MAX_NAME_SIZE = 80
  # conversations.setTopic and conversations.setPurpose: at most 250 characters.
  MAX_TEXT_SIZE = 250

  # Slack checks the allowed characters itself: its error names cover
  # punctuation and special characters separately.
  def self.name_issues(issues : Array(Slack::UI::ValidationIssue), prefix : String, name : String) : Nil
    if name.blank?
      issues << Slack::UI::ValidationIssue.new("#{prefix}.name.blank", "name", "Name must not be blank.")
    elsif name.size > MAX_NAME_SIZE
      issues << Slack::UI::ValidationIssue.new("#{prefix}.name.too_long", "name",
        "Name must be at most #{MAX_NAME_SIZE} characters.")
    end
  end

  def self.users_issues(issues : Array(Slack::UI::ValidationIssue), prefix : String, users : Array(String),
                        maximum : Int32) : Nil
    if users.empty?
      issues << Slack::UI::ValidationIssue.new("#{prefix}.users.empty", "users", "Supply at least one user ID.")
    elsif users.size > maximum
      issues << Slack::UI::ValidationIssue.new("#{prefix}.users.too_many", "users",
        "Supply at most #{maximum} user IDs.")
    end
  end

  def self.text_issues(issues : Array(Slack::UI::ValidationIssue), prefix : String, path : String,
                       text : String) : Nil
    return if text.size <= MAX_TEXT_SIZE

    issues << Slack::UI::ValidationIssue.new("#{prefix}.#{path}.too_long", path,
      "#{path.capitalize} must be at most #{MAX_TEXT_SIZE} characters.")
  end
end
