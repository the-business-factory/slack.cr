alias Slack::UI::Table::Cell = Slack::UI::Table::RawText |
                               Slack::UI::Table::RawNumber |
                               Slack::UI::Blocks::RichText

# Rows of raw text, raw number, or rich text cells. Slack lists messages and
# Home tabs as its surfaces, so modal unions exclude it.
#
# Slack also limits a table, and all tables in one message, to 10,000
# characters across all cells. Slack checks this limit; rich text cells have no
# documented character count.
struct Slack::UI::Blocks::Table
  include Slack::UI::ValueValidation

  ROWS_MAX_SIZE            = 100
  CELLS_MAX_SIZE           =  20
  COLUMN_SETTINGS_MAX_SIZE =  20

  @rows : Array(Array(Slack::UI::Table::Cell))
  @column_settings : Array(Slack::UI::Table::ColumnSetting?)?
  getter block_id : String?

  # A `nil` column setting sends `null`, which keeps Slack's defaults for that column.
  def initialize(rows : Enumerable(T), column_settings : Enumerable(U)? = nil, @block_id : String? = nil) forall T, U
    @rows = [] of Array(Slack::UI::Table::Cell)
    rows.each { |row| @rows << copy_row(row) }
    @column_settings = if column_settings
                         copied = [] of Slack::UI::Table::ColumnSetting?
                         column_settings.each { |setting| append_setting(copied, setting) }
                         copied
                       end
    validate!
  end

  def type : String
    "table"
  end

  def rows : Array(Array(Slack::UI::Table::Cell))
    @rows.map(&.dup)
  end

  def column_settings : Array(Slack::UI::Table::ColumnSetting?)?
    @column_settings.try(&.dup)
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    if @rows.empty?
      issues << ValidationIssue.new("table.rows.empty", "rows", "A table must contain at least one row.")
    elsif @rows.size > ROWS_MAX_SIZE
      issues << ValidationIssue.new("table.rows.too_many", "rows", "A table cannot contain more than #{ROWS_MAX_SIZE} rows.")
    end
    @rows.each_with_index { |row, index| row_issues(issues, row, "rows[#{index}]") }
    if (settings = @column_settings) && settings.size > COLUMN_SETTINGS_MAX_SIZE
      issues << ValidationIssue.new("table.column_settings.too_many", "column_settings", "A table cannot contain more than #{COLUMN_SETTINGS_MAX_SIZE} column settings.")
    end
    length_issue(issues, @block_id, 255, "table.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
      json.field "column_settings", @column_settings if @column_settings
      json.field "rows", @rows
    end
  end

  # Nonempty rows are library policy; Slack documents only the maximum.
  private def row_issues(issues : Array(ValidationIssue), row : Array(Slack::UI::Table::Cell), path : String) : Nil
    if row.empty?
      issues << ValidationIssue.new("table.row.empty", path, "A table row must contain at least one cell.")
    elsif row.size > CELLS_MAX_SIZE
      issues << ValidationIssue.new("table.row.too_many_cells", path, "A table row cannot contain more than #{CELLS_MAX_SIZE} cells.")
    end
    row.each_with_index do |cell, index|
      cell.validate.each { |issue| issues << issue.at("#{path}[#{index}]") }
    end
  end

  private def copy_row(row : Enumerable(T)) : Array(Slack::UI::Table::Cell) forall T
    cells = [] of Slack::UI::Table::Cell
    row.each { |cell| append_cell(cells, cell) }
    cells
  end

  private def append_cell(cells : Array(Slack::UI::Table::Cell), cell : Slack::UI::Table::Cell) : Nil
    cells << cell
  end

  private def append_setting(settings : Array(Slack::UI::Table::ColumnSetting?), setting : Slack::UI::Table::ColumnSetting?) : Nil
    settings << setting
  end
end
