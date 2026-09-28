alias Slack::UI::HomeBlock = Slack::UI::Blocks::Section |
                             Slack::UI::Blocks::Actions |
                             Slack::UI::Blocks::Divider |
                             Slack::UI::Blocks::Header |
                             Slack::UI::Blocks::Context |
                             Slack::UI::Blocks::Image |
                             Slack::UI::Blocks::Video |
                             Slack::UI::Blocks::RichText |
                             Slack::UI::Blocks::Table |
                             Slack::UI::Blocks::DataTable |
                             Slack::UI::Blocks::DataVisualization |
                             Slack::UI::Blocks::Card |
                             Slack::UI::Blocks::Carousel |
                             Slack::UI::Blocks::Container |
                             Slack::UI::Blocks::Input |
                             Slack::UI::Blocks::ViewInput

struct Slack::UI::Home
  include Slack::UI::ValueValidation

  @blocks : Array(HomeBlock)
  getter private_metadata : String?
  getter callback_id : String?
  getter external_id : String?

  def initialize(
    blocks : Enumerable(T),
    @private_metadata : String? = nil,
    @callback_id : String? = nil,
    @external_id : String? = nil,
  ) forall T
    @blocks = [] of HomeBlock
    blocks.each do |block|
      DeclaredTypes.non_modal_block(typeof(block))
      append_block(block)
    end
    validate!
  end

  def type : String
    "home"
  end

  def blocks : Array(HomeBlock)
    @blocks.dup
  end

  def snapshot : Home
    Home.new(blocks: @blocks, private_metadata: @private_metadata, callback_id: @callback_id, external_id: @external_id)
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    length_issue(issues, @private_metadata, 3000, "home.private_metadata.too_long", "private_metadata")
    length_issue(issues, @callback_id, 255, "home.callback_id.too_long", "callback_id")
    if @blocks.size > 100
      issues << ValidationIssue.new("home.blocks.too_many", "blocks", "Home cannot contain more than 100 blocks.")
    end
    BlockValidation.validate(@blocks, issues, "home.block_id.duplicate", "Block IDs must be unique within a view.")
    issues.concat(Slack::UI::ViewFocus.validate(@blocks, "home"))
    issues.concat(ChannelResponseUrl.non_modal_inputs(@blocks))
    issues.concat(WorkflowButtonPlacement.validate(@blocks, "home"))
    datetime_picker_issues(issues)
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "blocks", @blocks
      json.field "private_metadata", @private_metadata if @private_metadata
      json.field "callback_id", @callback_id if @callback_id
      json.field "external_id", @external_id if @external_id
    end
  end

  # Slack documents datetimepicker for messages and modals only, and remote
  # file blocks for messages only. Container children can hold either.
  private def datetime_picker_issues(issues : Array(ValidationIssue)) : Nil
    @blocks.each_with_index do |block, index|
      if block.is_a?(Blocks::Container)
        block.child_blocks.each_with_index do |child, position|
          surface_issues(issues, child, "blocks[#{index}].child_blocks[#{position}]")
        end
      else
        surface_issues(issues, block, "blocks[#{index}]")
      end
    end
  end

  private def surface_issues(issues : Array(ValidationIssue), block : HomeBlock | Blocks::Container::Child, path : String) : Nil
    case block
    when Blocks::Actions
      block.elements.each_with_index do |element, position|
        datetime_picker_issue(issues, "#{path}.elements[#{position}]") if element.is_a?(BlockElements::DatetimePicker)
      end
    when Blocks::Input
      datetime_picker_issue(issues, "#{path}.element") if block.element.is_a?(BlockElements::DatetimePicker)
    when Blocks::File
      issues << ValidationIssue.new("home.file.unsupported_surface", path, "Slack supports remote file blocks only in messages.")
    end
  end

  private def datetime_picker_issue(issues : Array(ValidationIssue), path : String) : Nil
    issues << ValidationIssue.new("home.datetimepicker.unsupported_surface", path, "Slack supports datetimepicker only in messages and modals.")
  end

  private def append_block(block : HomeBlock) : Nil
    @blocks << block
  end
end
