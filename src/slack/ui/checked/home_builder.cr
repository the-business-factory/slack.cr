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

  def add_all(blocks : Enumerable(T)) : Nil forall T
    DeclaredTypes.home_block(T)
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
