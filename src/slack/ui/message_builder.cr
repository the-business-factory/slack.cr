class Slack::UI::MessageBuilder
  include Slack::UI::DisplayBlockHelpers
  include Slack::UI::InputBlockHelpers
  include Slack::UI::NonModalBlockHelpers

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

  # Adds a plan of task cards. Home and modal builders do not have this
  # helper because Slack shows plans in messages only.
  def plan(title : String, tasks : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Blocks::Plan.new(title: title, tasks: tasks, block_id: block_id))
  end

  def build : Message
    if fallback_text = @fallback_text
      Message.new(fallback_text: fallback_text, blocks: @blocks)
    else
      Message.with_slack_generated_fallback(blocks: @blocks)
    end
  end
end
