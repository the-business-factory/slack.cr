class Slack::UI::Checked::HomeBuilder
  include Slack::UI::Checked::DisplayBlockHelpers
  include Slack::UI::Checked::InputBlockHelpers
  include Slack::UI::Checked::ViewInputBlockHelpers

  @blocks = [] of HomeBlock

  def initialize(
    @private_metadata : String? = nil,
    @callback_id : String? = nil,
    @external_id : String? = nil,
  )
  end

  def add(block : HomeBlock) : Nil
    @blocks << block
  end

  # Adds a table block. Modal builders do not have this helper because Slack
  # shows tables in messages and Home tabs only.
  def table(rows : Enumerable(T), column_settings : Enumerable(U)? = nil, block_id : String? = nil) : Nil forall T, U
    add(Blocks::Table.new(rows: rows, column_settings: column_settings, block_id: block_id))
  end

  # Adds a data table block. Modal builders do not have this helper because
  # Slack shows data tables in messages and Home tabs only.
  def data_table(caption : String, header : Enumerable(H), rows : Enumerable(R), page_size : Int32? = nil,
                 row_header_column_index : Int32? = nil, block_id : String? = nil) : Nil forall H, R
    add(Blocks::DataTable.new(caption: caption, header: header, rows: rows, page_size: page_size,
      row_header_column_index: row_header_column_index, block_id: block_id))
  end

  def add_all(blocks : Enumerable(T)) : Nil forall T
    blocks.each { |block| add(block) }
  end

  def build : Home
    Home.new(
      blocks: @blocks,
      private_metadata: @private_metadata,
      callback_id: @callback_id,
      external_id: @external_id
    )
  end
end
