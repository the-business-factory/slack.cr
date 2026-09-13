# Shared copying and validation for the static menu option lists.
module Slack::UI::Checked::OptionCollection
  def self.copy(options : Enumerable(T)) : Array(CompositionObjects::Option) forall T
    DeclaredTypes.option(T)
    copied = [] of CompositionObjects::Option
    options.each { |option| copied << option }
    copied
  end

  def self.copy(options : Nil) : Nil
    nil
  end

  def self.validate(options : Array(CompositionObjects::Option), issues : Array(ValidationIssue), path : String, code : String) : Nil
    if options.empty? || options.size > 100
      issues << ValidationIssue.new("#{code}.size", path, "Supply one to 100 options.")
    end
    values = Set(String).new
    options.each_with_index do |option, index|
      option.validate.each { |issue| issues << issue.at("#{path}[#{index}]") }
      unless values.add?(option.value)
        issues << ValidationIssue.new("#{code}.value.duplicate", "#{path}[#{index}].value", "Option values must be unique within the menu.")
      end
    end
  end
end
