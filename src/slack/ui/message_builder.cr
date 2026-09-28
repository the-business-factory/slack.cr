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

  # Adds a data table block. Modal builders do not have this helper because
  # Slack shows data tables in messages and Home tabs only.
  def data_table(caption : String, header : Enumerable(H), rows : Enumerable(R), page_size : Int32? = nil,
                 row_header_column_index : Int32? = nil, block_id : String? = nil) : Nil forall H, R
    add(Blocks::DataTable.new(caption: caption, header: header, rows: rows, page_size: page_size,
      row_header_column_index: row_header_column_index, block_id: block_id))
  end

  # Adds a table block. Modal builders do not have this helper because Slack
  # shows tables in messages and Home tabs only.
  def table(rows : Enumerable(T), column_settings : Enumerable(U)? = nil, block_id : String? = nil) : Nil forall T, U
    add(Blocks::Table.new(rows: rows, column_settings: column_settings, block_id: block_id))
  end

  # Adds a markdown block. Home and modal builders do not have this helper
  # because Slack shows markdown blocks in messages only.
  def markdown(text : String) : Nil
    add(Blocks::Markdown.new(text))
  end

  # Adds a context actions block. Home and modal builders do not have this
  # helper because Slack shows context actions in messages only.
  def context_actions(elements : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Blocks::ContextActions.new(elements: elements, block_id: block_id))
  end

  # Adds a data visualization block. Modal builders do not have this helper
  # because Slack shows charts in messages and Home tabs only.
  def data_visualization(title : String, chart : DataVisualization::Chart, block_id : String? = nil) : Nil
    add(Blocks::DataVisualization.new(title: title, chart: chart, block_id: block_id))
  end

  # Adds a carousel of cards. Modal builders do not have this helper because
  # Slack shows carousels in messages and Home tabs only.
  def carousel(elements : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Blocks::Carousel.new(elements: elements, block_id: block_id))
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
