# :nodoc:
# Included only by the Message and Home builders. Slack shows these blocks in
# messages and Home tabs, but not in modals.
module Slack::UI::NonModalBlockHelpers
  def table(rows : Enumerable(T), column_settings : Enumerable(U)? = nil, block_id : String? = nil) : Nil forall T, U
    add(Blocks::Table.new(rows: rows, column_settings: column_settings, block_id: block_id))
  end

  def data_table(caption : String, header : Enumerable(H), rows : Enumerable(R), page_size : Int32? = nil,
                 row_header_column_index : Int32? = nil, block_id : String? = nil) : Nil forall H, R
    add(Blocks::DataTable.new(caption: caption, header: header, rows: rows, page_size: page_size,
      row_header_column_index: row_header_column_index, block_id: block_id))
  end

  def data_visualization(title : String, chart : DataVisualization::Chart, block_id : String? = nil) : Nil
    add(Blocks::DataVisualization.new(title: title, chart: chart, block_id: block_id))
  end

  # Adds a carousel of cards.
  def carousel(elements : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Blocks::Carousel.new(elements: elements, block_id: block_id))
  end
end
