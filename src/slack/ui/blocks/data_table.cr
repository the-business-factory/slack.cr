# A paged, sortable table with a caption. Slack lists messages and Home tabs as
# its surfaces, so modal unions exclude it.
#
# Slack sends the header as the first entry of `rows`. The header is a separate
# argument here because header cells cannot be rich text: `HeaderCell` rejects
# `Blocks::RichText` at compile time. Every data row must have the same number
# of cells as the header. Issue paths name the constructor arguments, so
# `rows[0]` is the first data row.
#
# Slack also limits a data table, and all table cells in one message, to 20,000
# characters. Slack checks this limit; rich text cells have no documented
# character count. Slack's reference names interactive cells but gives no
# schema for them, so this block is display only.
struct Slack::UI::Blocks::DataTable
  include Slack::UI::ValueValidation

  alias HeaderCell = Slack::UI::Table::RawText | Slack::UI::Table::RawNumber

  ROWS_MAX_SIZE    = 200
  COLUMNS_MAX_SIZE =  20
  PAGE_SIZE_RANGE  = 1..100

  getter caption : String
  @header : Array(HeaderCell)
  @rows : Array(Array(Slack::UI::Table::Cell))
  getter page_size : Int32?
  getter row_header_column_index : Int32?
  getter block_id : String?

  def initialize(@caption : String, header : Enumerable(H), rows : Enumerable(R), @page_size : Int32? = nil,
                 @row_header_column_index : Int32? = nil, @block_id : String? = nil) forall H, R
    @header = [] of HeaderCell
    header.each { |cell| append_header_cell(cell) }
    @rows = [] of Array(Slack::UI::Table::Cell)
    rows.each { |row| @rows << copy_row(row) }
    validate!
  end

  def type : String
    "data_table"
  end

  def header : Array(HeaderCell)
    @header.dup
  end

  # Data rows, without the header.
  def rows : Array(Array(Slack::UI::Table::Cell))
    @rows.map(&.dup)
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    # Nonempty caption is library policy; Slack requires the field but states no length.
    issues << ValidationIssue.new("data_table.caption.empty", "caption", "Caption must not be empty.") if @caption.empty?
    header_issues(issues)
    rows_issues(issues)
    page_size = @page_size
    if page_size && !PAGE_SIZE_RANGE.includes?(page_size)
      issues << ValidationIssue.new("data_table.page_size.out_of_range", "page_size", "Page size must be from #{PAGE_SIZE_RANGE.begin} to #{PAGE_SIZE_RANGE.end}.")
    end
    row_header_issue(issues)
    length_issue(issues, @block_id, 255, "data_table.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
      json.field "caption", @caption
      json.field "page_size", @page_size if @page_size
      json.field "row_header_column_index", @row_header_column_index if @row_header_column_index
      json.field "rows" do
        json.array do
          json.array { @header.each(&.to_json(json)) }
          @rows.each(&.to_json(json))
        end
      end
    end
  end

  private def header_issues(issues : Array(ValidationIssue)) : Nil
    if @header.empty?
      issues << ValidationIssue.new("data_table.header.empty", "header", "A data table must contain at least one column.")
    elsif @header.size > COLUMNS_MAX_SIZE
      issues << ValidationIssue.new("data_table.header.too_many_cells", "header", "A data table cannot contain more than #{COLUMNS_MAX_SIZE} columns.")
    end
    @header.each_with_index do |cell, index|
      cell.validate.each { |issue| issues << issue.at("header[#{index}]") }
    end
  end

  private def rows_issues(issues : Array(ValidationIssue)) : Nil
    if @rows.empty?
      issues << ValidationIssue.new("data_table.rows.empty", "rows", "A data table must contain at least one data row.")
    elsif @rows.size > ROWS_MAX_SIZE
      issues << ValidationIssue.new("data_table.rows.too_many", "rows", "A data table cannot contain more than #{ROWS_MAX_SIZE} data rows.")
    end
    @rows.each_with_index do |row, row_index|
      path = "rows[#{row_index}]"
      unless row.size == @header.size
        issues << ValidationIssue.new("data_table.row.width_mismatch", path, "A data row must contain #{@header.size} cells, the same as the header.")
      end
      row.each_with_index do |cell, index|
        cell.validate.each { |issue| issues << issue.at("#{path}[#{index}]") }
      end
    end
  end

  # Slack documents a 0-based column index; an index inside the header is library policy.
  private def row_header_issue(issues : Array(ValidationIssue)) : Nil
    index = @row_header_column_index
    return unless index
    return if (0...@header.size).includes?(index)
    issues << ValidationIssue.new("data_table.row_header_column_index.out_of_range", "row_header_column_index", "Row header column index must name a header column.")
  end

  private def copy_row(row : Enumerable(T)) : Array(Slack::UI::Table::Cell) forall T
    cells = [] of Slack::UI::Table::Cell
    row.each { |cell| append_cell(cells, cell) }
    cells
  end

  private def append_header_cell(cell : HeaderCell) : Nil
    @header << cell
  end

  private def append_cell(cells : Array(Slack::UI::Table::Cell), cell : Slack::UI::Table::Cell) : Nil
    cells << cell
  end
end
