# A titled list of 1 to 50 task cards. See
# https://docs.slack.dev/reference/block-kit/blocks/plan-block.
#
# Slack shows plans in messages only. The reference calls the tasks
# "task-like objects without a type", but its SDK examples send task card
# blocks, so each task keeps `"type": "task_card"`.
struct Slack::UI::Blocks::Plan
  include Slack::UI::ValueValidation

  TASKS_MAX_SIZE = 50

  @tasks : Array(TaskCard)
  getter title : String
  getter block_id : String?

  def initialize(@title : String, tasks : Enumerable(T), @block_id : String? = nil) forall T
    @tasks = [] of TaskCard
    tasks.each { |task| append_task(task) }
    validate!
  end

  def type : String
    "plan"
  end

  def tasks : Array(TaskCard)
    @tasks.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    issues << ValidationIssue.new("plan.title.empty", "title", "Title must not be empty.") if @title.empty?
    if @tasks.empty?
      issues << ValidationIssue.new("plan.tasks.empty", "tasks", "A plan must contain at least one task.")
    elsif @tasks.size > TASKS_MAX_SIZE
      issues << ValidationIssue.new("plan.tasks.too_many", "tasks", "A plan cannot contain more than #{TASKS_MAX_SIZE} tasks.")
    end
    task_ids = Set(String).new
    @tasks.each_with_index do |task, index|
      task.validate.each { |issue| issues << issue.at("tasks[#{index}]") }
      next if task_ids.add?(task.task_id)

      issues << ValidationIssue.new("plan.task_id.duplicate", "tasks[#{index}].task_id", "Task IDs must be unique within a plan.")
    end
    length_issue(issues, @block_id, 255, "plan.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "title", @title
      json.field "tasks", @tasks
      json.field "block_id", @block_id if @block_id
    end
  end

  private def append_task(task : TaskCard) : Nil
    @tasks << task
  end
end
