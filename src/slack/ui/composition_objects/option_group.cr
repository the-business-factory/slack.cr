struct Slack::UI::Checked::CompositionObjects::OptionGroup
  include Slack::UI::Checked::ValueValidation

  getter label : PlainText
  @options : Array(Option)

  def initialize(*, @label : PlainText, options : Enumerable(T)) forall T
    @options = Slack::UI::Checked::OptionCollection.copy(options)
    validate!
  end

  def options : Array(Option)
    @options.dup
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = @label.validate.map(&.at("label"))
    length_issue(issues, @label.text, 75, "option_group.label.too_long", "label.text")
    Slack::UI::Checked::OptionCollection.validate(@options, issues, "options", "option_group.options")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "label", @label
      json.field "options", @options
    end
  end
end
