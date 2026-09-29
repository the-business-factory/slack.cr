struct Slack::UI::BlockElements::StaticSelect
  include Slack::UI::BlockElements::StaticSelectContent

  getter initial_option : Option?

  def initialize(
    *,
    options : Enumerable(T),
    action_id : (String | Slack::UI::ActionId)? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
    @initial_option : Option? = nil,
  ) forall T
    @action_id = Slack::UI::ActionId.value_of(action_id)
    @options = Slack::UI::OptionCollection.copy(options)
    @option_groups = nil
    validate!
  end

  def initialize(
    *,
    option_groups : Enumerable(T),
    action_id : (String | Slack::UI::ActionId)? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
    @initial_option : Option? = nil,
  ) forall T
    @action_id = Slack::UI::ActionId.value_of(action_id)
    @options = nil
    @option_groups = copy_groups(option_groups)
    validate!
  end

  def type : String
    "static_select"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = validate_content
    if initial = @initial_option
      validate_initial(initial, issues, "initial_option")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      serialize_content(json)
      json.field "initial_option", @initial_option if @initial_option
    end
  end
end
