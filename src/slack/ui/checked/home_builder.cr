class Slack::UI::Checked::HomeBuilder
  include Slack::UI::Checked::DisplayBlockHelpers
  include Slack::UI::Checked::InputBlockHelpers

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
