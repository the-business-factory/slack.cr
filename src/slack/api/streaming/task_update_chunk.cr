# The state of one task. A later chunk with the same *id* updates that task.
#
# Slack limits `task_update` chunks to 256 characters. The library applies the
# limit to `title`; Slack does not say how the limit applies to other fields.
struct Slack::Api::Streaming::TaskUpdateChunk
  include Slack::UI::ValueValidation

  TITLE_MAX_SIZE = 256

  getter id : String
  getter title : String
  getter status : Slack::UI::TaskStatus
  getter hide_title : Bool?
  getter icon : IconRef?
  getter details : String?
  getter output : String?

  @sources : Array(Slack::UI::BlockElements::UrlSource)?

  def initialize(
    @id : String,
    @title : String,
    @status : Slack::UI::TaskStatus,
    @hide_title : Bool? = nil,
    @icon : IconRef? = nil,
    @details : String? = nil,
    @output : String? = nil,
    sources : Enumerable(Slack::UI::BlockElements::UrlSource)? = nil,
  )
    # `Array#to_a` returns the same array, so copy through `map`.
    @sources = sources.try(&.map(&.itself))
    validate!
  end

  def sources : Array(Slack::UI::BlockElements::UrlSource)?
    @sources.dup
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @id.empty?
      issues << Slack::UI::ValidationIssue.new("task_update.id.empty", "id", "Task ID must not be empty.")
    end
    if @title.empty?
      issues << Slack::UI::ValidationIssue.new("task_update.title.empty", "title", "Title must not be empty.")
    end
    length_issue(issues, @title, TITLE_MAX_SIZE, "task_update.title.too_long", "title")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", "task_update"
      json.field "id", @id
      json.field "title", @title
      json.field "status", @status.wire_value
      json.field "hide_title", @hide_title unless @hide_title.nil?
      json.field "icon", @icon if @icon
      json.field "details", @details if @details
      json.field "output", @output if @output
      json.field "sources", @sources if @sources
    end
  end
end
