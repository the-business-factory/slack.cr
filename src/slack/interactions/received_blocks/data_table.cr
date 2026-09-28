# A received `data_table` block. The first row is the header row.
# https://docs.slack.dev/reference/block-kit/blocks/data-table-block/
struct Slack::Interactions::ReceivedBlocks::DataTable
  getter raw : JSON::Any
  getter block_id : String?
  getter caption : String
  getter page_size : Int32?
  getter row_header_column_index : Int32?
  @rows : Array(Array(TableCell))

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @caption = Decoder.string(object, "caption", path)
    @rows = Decoder.rows(object, path)
    @page_size = Decoder.int32?(object, "page_size", path)
    @row_header_column_index = Decoder.int32?(object, "row_header_column_index", path)
  end

  def rows : Array(Array(TableCell))
    @rows.map(&.dup)
  end
end
