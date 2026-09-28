class Slack::UI::Checked::MessageBuilder
  include Slack::UI::Checked::DisplayBlockHelpers
  include Slack::UI::Checked::InputBlockHelpers

  @blocks : Array(MessageBlock)
  @fallback_text : String?

  def initialize(@fallback_text : String)
    @blocks = [] of MessageBlock
  end

  def self.with_slack_generated_fallback : MessageBuilder
    new(fallback_text: nil)
  end

  private def initialize(@fallback_text : Nil)
    @blocks = [] of MessageBlock
  end

  def add(block : MessageBlock) : Nil
    @blocks << block
  end

  # Adds a remote file block. Home and modal builders do not have this helper.
  # Slack does not accept direct posts of this block; see `Blocks::File`.
  def file(external_id : String, block_id : String? = nil) : Nil
    add(Blocks::File.new(external_id: external_id, block_id: block_id))
  end

  # Adds a table block. Modal builders do not have this helper because Slack
  # shows tables in messages and Home tabs only.
  def table(rows : Enumerable(T), column_settings : Enumerable(U)? = nil, block_id : String? = nil) : Nil forall T, U
    add(Blocks::Table.new(rows: rows, column_settings: column_settings, block_id: block_id))
  end

  def add_all(blocks : Enumerable(T)) : Nil forall T
    blocks.each { |block| add(block) }
  end

  def build : Message
    if fallback_text = @fallback_text
      Message.new(fallback_text: fallback_text, blocks: @blocks)
    else
      Message.with_slack_generated_fallback(blocks: @blocks)
    end
  end
end
