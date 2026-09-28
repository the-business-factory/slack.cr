alias Slack::UI::Checked::HomeBlock = Slack::UI::Checked::Blocks::Section |
                                      Slack::UI::Checked::Blocks::Actions |
                                      Slack::UI::Checked::Blocks::Divider |
                                      Slack::UI::Checked::Blocks::Header |
                                      Slack::UI::Checked::Blocks::Context |
                                      Slack::UI::Checked::Blocks::Image |
                                      Slack::UI::Checked::Blocks::Video |
                                      Slack::UI::Checked::Blocks::RichText |
                                      Slack::UI::Checked::Blocks::Input

struct Slack::UI::Checked::Home
  include Slack::UI::Checked::ValueValidation

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
    blocks.each { |block| append_block(block) }
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
    issues.concat(Slack::UI::Checked::ViewFocus.validate(@blocks, "home"))
    issues.concat(ChannelResponseUrl.non_modal_inputs(@blocks))
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

  # Slack documents datetimepicker for messages and modals only.
  private def datetime_picker_issues(issues : Array(ValidationIssue)) : Nil
    @blocks.each_with_index do |block, index|
      case block
      when Blocks::Actions
        block.elements.each_with_index do |element, position|
          datetime_picker_issue(issues, "blocks[#{index}].elements[#{position}]") if element.is_a?(BlockElements::DatetimePicker)
        end
      when Blocks::Input
        datetime_picker_issue(issues, "blocks[#{index}].element") if block.element.is_a?(BlockElements::DatetimePicker)
      end
    end
  end

  private def datetime_picker_issue(issues : Array(ValidationIssue), path : String) : Nil
    issues << ValidationIssue.new("home.datetimepicker.unsupported_surface", path, "Slack supports datetimepicker only in messages and modals.")
  end

  private def append_block(block : HomeBlock) : Nil
    @blocks << block
  end
end
