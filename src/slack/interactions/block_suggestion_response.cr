# Outbound JSON body for a block_suggestion request. Return it in an HTTP 200
# `application/json` response within three seconds. Slack accepts up to 100
# options, or up to 100 option groups of up to 100 options each. An empty
# options list shows no results for the query.
struct Slack::Interactions::BlockSuggestionResponse
  include Slack::UI::Checked::ValueValidation

  alias Option = Slack::UI::Checked::CompositionObjects::Option
  alias OptionGroup = Slack::UI::Checked::CompositionObjects::OptionGroup

  MAX_SIZE = 100

  @options : Array(Option)?
  @option_groups : Array(OptionGroup)?

  def initialize(*, options : Enumerable(T)) forall T
    @options = Slack::UI::Checked::OptionCollection.copy(options)
    validate!
  end

  def initialize(*, option_groups : Enumerable(T)) forall T
    copied = [] of OptionGroup
    option_groups.each { |group| copied << group }
    @option_groups = copied
    validate!
  end

  def options : Array(Option)?
    @options.try(&.dup)
  end

  def option_groups : Array(OptionGroup)?
    @option_groups.try(&.dup)
  end

  # Values must be unique across the whole response so a selection identifies
  # one option; this is library policy shared with static menus.
  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if options = @options
      validate_options(options, issues)
    end
    if groups = @option_groups
      validate_groups(groups, issues)
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "options", @options if @options
      json.field "option_groups", @option_groups if @option_groups
    end
  end

  private def validate_options(options : Array(Option), issues : Array(Slack::UI::Checked::ValidationIssue)) : Nil
    if options.size > MAX_SIZE
      issues << Slack::UI::Checked::ValidationIssue.new("block_suggestion_response.options.size", "options", "Supply at most 100 options.")
    end
    values = Set(String).new
    options.each_with_index do |option, index|
      option.validate.each { |issue| issues << issue.at("options[#{index}]") }
      unless values.add?(option.value)
        issues << Slack::UI::Checked::ValidationIssue.new("block_suggestion_response.options.value.duplicate", "options[#{index}].value", "Option values must be unique within the response.")
      end
    end
  end

  private def validate_groups(groups : Array(OptionGroup), issues : Array(Slack::UI::Checked::ValidationIssue)) : Nil
    if groups.size > MAX_SIZE
      issues << Slack::UI::Checked::ValidationIssue.new("block_suggestion_response.option_groups.size", "option_groups", "Supply at most 100 option groups.")
    end
    values = Set(String).new
    groups.each_with_index do |group, index|
      group.validate.each { |issue| issues << issue.at("option_groups[#{index}]") }
      group.options.each_with_index do |option, option_index|
        unless values.add?(option.value)
          issues << Slack::UI::Checked::ValidationIssue.new("block_suggestion_response.options.value.duplicate", "option_groups[#{index}].options[#{option_index}].value", "Option values must be unique within the response.")
        end
      end
    end
  end
end
