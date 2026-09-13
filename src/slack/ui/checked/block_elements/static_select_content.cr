# Shared static-source fields; the two elements keep separate selection contracts.
module Slack::UI::Checked::BlockElements::StaticSelectContent
  include Slack::UI::Checked::ValueValidation

  alias Option = Slack::UI::Checked::CompositionObjects::Option
  alias OptionGroup = Slack::UI::Checked::CompositionObjects::OptionGroup

  @options : Array(Option)?
  @option_groups : Array(OptionGroup)?
  getter action_id : String?
  getter placeholder : Slack::UI::Checked::CompositionObjects::PlainText?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def options : Array(Option)?
    @options.try(&.dup)
  end

  def option_groups : Array(OptionGroup)?
    @option_groups.try(&.dup)
  end

  private def copy_groups(groups : Enumerable(T)) : Array(OptionGroup) forall T
    Slack::UI::Checked::DeclaredTypes.option_group(T)
    copied = [] of OptionGroup
    groups.each { |group| copied << group }
    copied
  end

  private def available_options : Array(Option)
    @options || @option_groups.try(&.flat_map(&.options)) || [] of Option
  end

  private def validate_content : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "#{type}.placeholder.too_long", "placeholder.text")
    end
    if confirm = @confirm
      confirm.validate.each { |issue| issues << issue.at("confirm") }
    end
    if options = @options
      Slack::UI::Checked::OptionCollection.validate(options, issues, "options", "#{type}.options")
    end
    if groups = @option_groups
      if groups.empty? || groups.size > 100
        issues << Slack::UI::Checked::ValidationIssue.new("#{type}.option_groups.size", "option_groups", "Supply one to 100 option groups.")
      end
      values = Set(String).new
      groups.each_with_index do |group, index|
        group.validate.each { |issue| issues << issue.at("option_groups[#{index}]") }
        group.options.each_with_index do |option, option_index|
          unless values.add?(option.value)
            issues << Slack::UI::Checked::ValidationIssue.new("#{type}.options.value.duplicate", "option_groups[#{index}].options[#{option_index}].value", "Option values must be unique within the menu.")
          end
        end
      end
    end
    issues
  end

  private def validate_initial(option : Option, issues : Array(Slack::UI::Checked::ValidationIssue), path : String) : Nil
    option.validate.each { |issue| issues << issue.at(path) }
    unless available_options.includes?(option)
      issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_option.not_found", path, "Initial option must exactly match an available option.")
    end
  end

  private def serialize_content(json : JSON::Builder) : Nil
    json.field "type", type
    json.field "options", @options if @options
    json.field "option_groups", @option_groups if @option_groups
    json.field "action_id", @action_id if @action_id
    json.field "placeholder", @placeholder if @placeholder
    json.field "confirm", @confirm if @confirm
    json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
  end
end
