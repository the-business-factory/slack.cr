# A received `table` block. `column_settings` stays raw JSON.
# https://docs.slack.dev/reference/block-kit/blocks/table-block/
struct Slack::Interactions::ReceivedBlocks::Table
  getter raw : JSON::Any
  getter block_id : String?
  getter column_settings : JSON::Any?
  @rows : Array(Array(TableCell))

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @rows = Decoder.rows(object, path)
    @column_settings = Decoder.raw?(object, "column_settings")
  end

  def rows : Array(Array(TableCell))
    @rows.map(&.dup)
  end
end
