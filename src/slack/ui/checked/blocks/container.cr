# Groups up to ten child blocks under a title. Slack lists messages and Home
# tabs as its surfaces, so modal unions exclude it.
#
# Slack requires `title`, `rich_text_title`, or both; the constructors require
# one of them at compile time. When both are sent, Slack shows
# `rich_text_title`. Slack does not list `container` as a child, so containers
# do not nest.
struct Slack::UI::Checked::Blocks::Container
  include Slack::UI::Checked::ValueValidation

  # The child blocks that Slack documents for a container. `Home` also rejects
  # a `File` child, because Slack shows remote file blocks in messages only.
  alias Child = Section | Actions | Context | Divider | File | Header | Image | Input | RichText | Table | Video

  # Slack uses `standard` when `width` is omitted.
  enum Width
    Narrow
    Standard
    Wide
    Full

    def wire_value : String
      case self
      in .narrow?   then "narrow"
      in .standard? then "standard"
      in .wide?     then "wide"
      in .full?     then "full"
      end
    end
  end

  CHILD_BLOCKS_MAX_SIZE =  10
  TEXT_MAX_LENGTH       = 150

  @child_blocks : Array(Child)
  getter title : CompositionObjects::PlainText?
  getter rich_text_title : RichText?
  getter subtitle : CompositionObjects::Text?
  getter width : Width?
  getter icon : BlockElements::Image?
  getter is_collapsible : Bool?
  getter default_collapsed : Bool?
  getter has_header_divider : Bool?
  getter block_id : String?

  # Slack uses `default_collapsed` only when `is_collapsible` is true, and
  # `has_header_divider` only when it is not. Both are sent as given.
  def initialize(
    *,
    @title : CompositionObjects::PlainText,
    child_blocks : Enumerable(T),
    @rich_text_title : RichText? = nil,
    @subtitle : CompositionObjects::Text? = nil,
    @width : Width? = nil,
    @icon : BlockElements::Image? = nil,
    @is_collapsible : Bool? = nil,
    @default_collapsed : Bool? = nil,
    @has_header_divider : Bool? = nil,
    @block_id : String? = nil,
  ) forall T
    @child_blocks = copy_children(child_blocks)
    validate!
  end

  def initialize(
    *,
    @rich_text_title : RichText,
    child_blocks : Enumerable(T),
    @subtitle : CompositionObjects::Text? = nil,
    @width : Width? = nil,
    @icon : BlockElements::Image? = nil,
    @is_collapsible : Bool? = nil,
    @default_collapsed : Bool? = nil,
    @has_header_divider : Bool? = nil,
    @block_id : String? = nil,
  ) forall T
    @title = nil
    @child_blocks = copy_children(child_blocks)
    validate!
  end

  def type : String
    "container"
  end

  def child_blocks : Array(Child)
    @child_blocks.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    text_issues(issues)
    if icon = @icon
      icon.validate.each { |issue| issues << issue.at("icon") }
      length_issue(issues, icon.alt_text, 2000, "container.icon.alt_text.too_long", "icon.alt_text")
    end
    child_block_issues(issues)
    length_issue(issues, @block_id, 255, "container.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
      json.field "title", @title if @title
      json.field "rich_text_title", @rich_text_title if @rich_text_title
      json.field "subtitle", @subtitle if @subtitle
      if width = @width
        json.field "width", width.wire_value
      end
      json.field "icon", @icon if @icon
      json.field "is_collapsible", @is_collapsible unless @is_collapsible.nil?
      json.field "default_collapsed", @default_collapsed unless @default_collapsed.nil?
      json.field "has_header_divider", @has_header_divider unless @has_header_divider.nil?
      json.field "child_blocks", @child_blocks
    end
  end

  private def text_issues(issues : Array(ValidationIssue)) : Nil
    if title = @title
      title.validate.each { |issue| issues << issue.at("title") }
      length_issue(issues, title.text, TEXT_MAX_LENGTH, "container.title.too_long", "title.text")
    end
    @rich_text_title.try(&.validate.each { |issue| issues << issue.at("rich_text_title") })
    if subtitle = @subtitle
      subtitle.validate.each { |issue| issues << issue.at("subtitle") }
      length_issue(issues, subtitle.text, TEXT_MAX_LENGTH, "container.subtitle.too_long", "subtitle.text")
    end
  end

  # One or more children is library policy; Slack documents only the maximum.
  private def child_block_issues(issues : Array(ValidationIssue)) : Nil
    if @child_blocks.empty?
      issues << ValidationIssue.new("container.child_blocks.empty", "child_blocks", "A container must contain at least one child block.")
    elsif @child_blocks.size > CHILD_BLOCKS_MAX_SIZE
      issues << ValidationIssue.new("container.child_blocks.too_many", "child_blocks", "A container cannot contain more than #{CHILD_BLOCKS_MAX_SIZE} child blocks.")
    end
    @child_blocks.each_with_index do |child, index|
      child.validate.each { |issue| issues << issue.at("child_blocks[#{index}]") }
    end
  end

  private def copy_children(child_blocks : Enumerable(T)) : Array(Child) forall T
    copied = [] of Child
    child_blocks.each { |child| append_child(copied, child) }
    copied
  end

  private def append_child(children : Array(Child), child : Child) : Nil
    children << child
  end
end
