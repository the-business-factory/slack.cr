alias Slack::UI::MessageSourceBlock = Slack::UI::Blocks::Section |
                                      Slack::UI::Blocks::Actions |
                                      Slack::UI::Blocks::Divider |
                                      Slack::UI::Blocks::Header |
                                      Slack::UI::Blocks::Context |
                                      Slack::UI::Blocks::Image |
                                      Slack::UI::Blocks::Video |
                                      Slack::UI::Blocks::File |
                                      Slack::UI::Blocks::RichText |
                                      Slack::UI::Blocks::Table |
                                      Slack::UI::Blocks::Markdown |
                                      Slack::UI::Blocks::ContextActions |
                                      Slack::UI::Blocks::DataTable |
                                      Slack::UI::Blocks::DataVisualization |
                                      Slack::UI::Blocks::Card |
                                      Slack::UI::Blocks::Carousel |
                                      Slack::UI::Blocks::Container |
                                      Slack::UI::Blocks::Input |
                                      Slack::UI::Blocks::Plan |
                                      Slack::UI::Blocks::TaskCard

alias Slack::UI::MessageBlock = Slack::UI::MessageSourceBlock

struct Slack::UI::Message
  BLOCKS_MAX_SIZE = 50

  # Slack's data visualization reference permits two of these blocks per message.
  DATA_VISUALIZATION_BLOCKS_MAX_SIZE = 2

  @blocks : Array(MessageBlock)
  @fallback_text : String?

  getter fallback_text : String?

  def initialize(@fallback_text : String, blocks : Enumerable(T)) forall T
    @blocks = copy_blocks(blocks)
    validate!
  end

  def self.with_slack_generated_fallback(blocks : Enumerable(T)) : Message forall T
    new(blocks: blocks, fallback_text: nil)
  end

  private def initialize(blocks : Enumerable(T), @fallback_text : Nil) forall T
    @blocks = copy_blocks(blocks)
    validate!
  end

  def blocks : Array(MessageBlock)
    @blocks.dup
  end

  def slack_generated_fallback? : Bool
    @fallback_text.nil?
  end

  def snapshot : Message
    if fallback_text = @fallback_text
      Message.new(fallback_text: fallback_text, blocks: @blocks)
    else
      Message.with_slack_generated_fallback(blocks: @blocks)
    end
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @blocks.empty?
      issues << Slack::UI::ValidationIssue.new(
        code: "message.blocks.empty",
        path: "blocks",
        message: "A Block Kit message must contain at least one block."
      )
    elsif @blocks.size > BLOCKS_MAX_SIZE
      issues << Slack::UI::ValidationIssue.new(
        code: "message.blocks.too_many",
        path: "blocks",
        message: "A message cannot contain more than #{BLOCKS_MAX_SIZE} blocks."
      )
    end

    if @blocks.count(&.is_a?(Blocks::DataVisualization)) > DATA_VISUALIZATION_BLOCKS_MAX_SIZE
      issues << Slack::UI::ValidationIssue.new(
        code: "message.data_visualization.too_many",
        path: "blocks",
        message: "A message cannot contain more than #{DATA_VISUALIZATION_BLOCKS_MAX_SIZE} data visualization blocks."
      )
    end

    if @fallback_text.try(&.empty?)
      issues << Slack::UI::ValidationIssue.new(
        code: "message.fallback_text.empty",
        path: "fallback_text",
        message: "Fallback text must not be empty."
      )
    end

    BlockValidation.validate(@blocks, issues, "message.block_id.duplicate", "Block IDs must be unique within a message.")
    markdown_size_issue(issues)
    issues.concat(ChannelResponseUrl.non_modal_inputs(@blocks))
    issues
  end

  def validate! : Nil
    issues = validate
    raise Slack::UI::ValidationError.new(issues) unless issues.empty?
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "text", @fallback_text if @fallback_text
      json.field "blocks" do
        blocks_to_json(json)
      end
    end
  end

  def blocks_to_json(json : JSON::Builder) : Nil
    json.array do
      @blocks.each(&.to_json(json))
    end
  end

  # Slack limits the text of all markdown blocks in one payload.
  private def markdown_size_issue(issues : Array(Slack::UI::ValidationIssue)) : Nil
    size = @blocks.sum { |block| block.is_a?(Blocks::Markdown) ? block.text.size : 0 }
    return unless size > Blocks::Markdown::TEXT_MAX_SIZE

    issues << Slack::UI::ValidationIssue.new(
      code: "message.markdown.too_long",
      path: "blocks",
      message: "The markdown blocks in a message cannot contain more than #{Blocks::Markdown::TEXT_MAX_SIZE} characters in total."
    )
  end

  private def copy_blocks(blocks : Enumerable(T)) : Array(MessageBlock) forall T
    copied = [] of MessageBlock
    blocks.each do |block|
      DeclaredTypes.non_modal_block(typeof(block))
      append_block(copied, block)
    end
    copied
  end

  private def append_block(blocks : Array(MessageBlock), block : MessageBlock) : Nil
    blocks << block
  end
end
