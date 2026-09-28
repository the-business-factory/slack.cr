# One task of an AI app: its status, optional details and output, and the
# sources it used. See https://docs.slack.dev/reference/block-kit/blocks/task-card-block.
#
# Slack shows task cards in messages only. A task card can stand alone or be
# one of the tasks of a `Plan`. The documented `icon` field has no schema, so
# the library does not send it. `TaskStatus::Pending` comes from the Slack SDKs.
struct Slack::UI::Blocks::TaskCard
  include Slack::UI::ValueValidation

  getter task_id : String
  getter title : String
  getter status : TaskStatus
  getter details : Blocks::RichText?
  getter output : Blocks::RichText?
  getter hide_title : Bool?
  getter block_id : String?

  @sources : Array(BlockElements::UrlSource)?

  def initialize(
    @task_id : String,
    @title : String,
    @status : TaskStatus,
    @details : Blocks::RichText? = nil,
    @output : Blocks::RichText? = nil,
    sources : Enumerable(BlockElements::UrlSource)? = nil,
    @hide_title : Bool? = nil,
    @block_id : String? = nil,
  )
    # `Array#to_a` returns the same array, so copy through `map`.
    @sources = sources.try(&.map(&.itself))
    validate!
  end

  def type : String
    "task_card"
  end

  def sources : Array(BlockElements::UrlSource)?
    @sources.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    issues << ValidationIssue.new("task_card.task_id.empty", "task_id", "Task ID must not be empty.") if @task_id.empty?
    issues << ValidationIssue.new("task_card.title.empty", "title", "Title must not be empty.") if @title.empty?
    @details.try(&.validate.each { |issue| issues << issue.at("details") })
    @output.try(&.validate.each { |issue| issues << issue.at("output") })
    length_issue(issues, @block_id, 255, "task_card.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "task_id", @task_id
      json.field "title", @title
      json.field "status", @status.wire_value
      json.field "details", @details if @details
      json.field "output", @output if @output
      json.field "sources", @sources if @sources
      json.field "hide_title", @hide_title unless @hide_title.nil?
      json.field "block_id", @block_id if @block_id
    end
  end
end
