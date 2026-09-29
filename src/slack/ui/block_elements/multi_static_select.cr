struct Slack::UI::BlockElements::MultiStaticSelect
  include Slack::UI::BlockElements::StaticSelectContent

  @initial_options : Array(Option)?
  getter max_selected_items : Int32?

  def initialize(
    *,
    options : Enumerable(T),
    action_id : (String | Slack::UI::ActionId)? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
    initial_options : Enumerable(U)? = nil,
    @max_selected_items : Int32? = nil,
  ) forall T, U
    @action_id = Slack::UI::ActionId.value_of(action_id)
    @options = Slack::UI::OptionCollection.copy(options)
    @option_groups = nil
    @initial_options = Slack::UI::OptionCollection.copy(initial_options)
    validate!
  end

  def initialize(
    *,
    option_groups : Enumerable(T),
    action_id : (String | Slack::UI::ActionId)? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
    initial_options : Enumerable(U)? = nil,
    @max_selected_items : Int32? = nil,
  ) forall T, U
    @action_id = Slack::UI::ActionId.value_of(action_id)
    @options = nil
    @option_groups = copy_groups(option_groups)
    @initial_options = Slack::UI::OptionCollection.copy(initial_options)
    validate!
  end

  def type : String
    "multi_static_select"
  end

  def initial_options : Array(Option)?
    @initial_options.try(&.dup)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = validate_content
    if maximum = @max_selected_items
      if maximum < 1
        issues << Slack::UI::ValidationIssue.new("#{type}.max_selected_items.too_small", "max_selected_items", "Maximum selected items must be at least one.")
      end
    end
    if initial = @initial_options
      if maximum = @max_selected_items
        if initial.size > maximum
          issues << Slack::UI::ValidationIssue.new("#{type}.initial_options.too_many", "initial_options", "Initial selections cannot exceed maximum selected items.")
        end
      end
      values = Set(String).new
      initial.each_with_index do |option, index|
        validate_initial(option, issues, "initial_options[#{index}]")
        unless values.add?(option.value)
          issues << Slack::UI::ValidationIssue.new("#{type}.initial_options.duplicate", "initial_options[#{index}]", "Initial selections must be distinct.")
        end
      end
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      serialize_content(json)
      json.field "initial_options", @initial_options if @initial_options
      json.field "max_selected_items", @max_selected_items if @max_selected_items
    end
  end
end
