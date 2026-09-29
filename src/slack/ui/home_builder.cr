class Slack::UI::HomeBuilder
  include Slack::UI::DisplayBlockHelpers
  include Slack::UI::InputBlockHelpers
  include Slack::UI::NonModalBlockHelpers
  include Slack::UI::ViewInputBlockHelpers

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

  def build : Home
    Home.new(
      blocks: @blocks,
      private_metadata: @private_metadata,
      callback_id: @callback_id,
      external_id: @external_id
    )
  end
end
