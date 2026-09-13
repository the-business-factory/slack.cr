alias Slack::UI::Checked::MessageSourceBlock = Slack::UI::Checked::Blocks::Section |
                                               Slack::UI::Checked::Blocks::Actions |
                                               Slack::UI::Checked::Blocks::Divider

alias Slack::UI::Checked::MessageBlock = Slack::UI::Checked::MessageSourceBlock

struct Slack::UI::Checked::Message
  BLOCKS_MAX_SIZE = 50

  @blocks : Array(MessageBlock)
  @fallback_text : String?

  getter fallback_text : String?

  def initialize(@fallback_text : String, blocks : Enumerable(T)) forall T
    Slack::UI::Checked::DeclaredTypes.message_block(T)
    @blocks = copy_blocks(blocks)
    validate!
  end

  def self.with_slack_generated_fallback(blocks : Enumerable(T)) : Message forall T
    new(blocks: blocks, fallback_text: nil)
  end

  private def initialize(blocks : Enumerable(T), @fallback_text : Nil) forall T
    Slack::UI::Checked::DeclaredTypes.message_block(T)
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

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @blocks.empty?
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "message.blocks.empty",
        path: "blocks",
        message: "A Block Kit message must contain at least one block."
      )
    elsif @blocks.size > BLOCKS_MAX_SIZE
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "message.blocks.too_many",
        path: "blocks",
        message: "A message cannot contain more than #{BLOCKS_MAX_SIZE} blocks."
      )
    end

    if @fallback_text.try(&.empty?)
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "message.fallback_text.empty",
        path: "fallback_text",
        message: "Fallback text must not be empty."
      )
    end

    block_ids = {} of String => Int32
    @blocks.each_with_index do |block, index|
      block.validate.each { |issue| issues << issue.at("blocks[#{index}]") }
      if block_id = block.block_id
        if block_ids.has_key?(block_id)
          issues << Slack::UI::Checked::ValidationIssue.new(
            code: "message.block_id.duplicate",
            path: "blocks[#{index}].block_id",
            message: "Block IDs must be unique within a message."
          )
        else
          block_ids[block_id] = index
        end
      end
    end
    issues
  end

  def validate! : Nil
    issues = validate
    raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?
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

  private def copy_blocks(blocks : Enumerable(T)) : Array(MessageBlock) forall T
    copied = [] of MessageBlock
    blocks.each { |block| append_block(copied, block) }
    copied
  end

  private def append_block(blocks : Array(MessageBlock), block : Slack::UI::Checked::Blocks::Section) : Nil
    blocks << block
  end

  private def append_block(blocks : Array(MessageBlock), block : Slack::UI::Checked::Blocks::Actions) : Nil
    blocks << block
  end

  private def append_block(blocks : Array(MessageBlock), block : Slack::UI::Checked::Blocks::Divider) : Nil
    blocks << block
  end
end
