# Accepts uploaded files in a FormModal input. Slack cannot dispatch it as an action.
struct Slack::UI::BlockElements::FileInput
  include Slack::UI::ValueValidation

  MAX_FILES_RANGE = 1..10

  @filetypes : Array(String)?
  getter action_id : String?
  getter max_files : Int32?

  def initialize(
    *,
    action_id : (String | Slack::UI::ActionId)? = nil,
    filetypes : Enumerable(T)? = nil,
    @max_files : Int32? = nil,
  ) forall T
    @action_id = Slack::UI::ActionId.value_of(action_id)
    @filetypes = if filetypes
                   copied = [] of String
                   filetypes.each { |filetype| copied << filetype }
                   copied
                 end
    validate!
  end

  def type : String
    "file_input"
  end

  # Slack treats these extensions as a convenience filter; check received files in the application.
  def filetypes : Array(String)?
    @filetypes.try(&.dup)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if (maximum = @max_files) && !MAX_FILES_RANGE.includes?(maximum)
      issues << Slack::UI::ValidationIssue.new("#{type}.max_files.out_of_range", "max_files", "Maximum files must be from 1 through 10.")
    end
    if filetypes = @filetypes
      if filetypes.empty?
        issues << Slack::UI::ValidationIssue.new("#{type}.filetypes.empty", "filetypes", "Omit filetypes to accept all file extensions.")
      end
      filetypes.each_with_index do |filetype, index|
        if filetype.blank?
          issues << Slack::UI::ValidationIssue.new("#{type}.filetypes.blank", "filetypes[#{index}]", "File extension must not be blank.")
        end
      end
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "filetypes", @filetypes if @filetypes
      json.field "max_files", @max_files if @max_files
    end
  end
end
