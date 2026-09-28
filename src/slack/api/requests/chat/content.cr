# :nodoc:
# The content of a chat message request: Block Kit blocks with their fallback
# text, plain `text`, or `markdown_text`, plus optional attachments.
#
# Requests choose one content kind through their constructors, so this type
# never holds `markdown_text` together with `text` or blocks. It copies the
# message and the attachments once. Issue codes start with the request prefix.
struct Slack::Api::ChatContent
  # Slack's documented maximum for one request. The attachments guide advises
  # at most 20.
  ATTACHMENTS_MAX_SIZE   =    100
  MARKDOWN_TEXT_MAX_SIZE = 12_000

  @message : Slack::UI::Message?
  @attachments : Array(Slack::UI::Attachment)?

  getter text : String?
  getter markdown_text : String?

  def initialize(*, message : Slack::UI::Message? = nil, @text : String? = nil, @markdown_text : String? = nil,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil)
    @message = message.try(&.snapshot)
    # `map` copies an Array argument; `to_a` would return the caller's Array.
    @attachments = attachments.try(&.map(&.itself))
  end

  def message : Slack::UI::Message?
    @message.try(&.snapshot)
  end

  def attachments : Array(Slack::UI::Attachment)?
    @attachments.try(&.dup)
  end

  # The top-level `text` field: the message fallback text or the plain text.
  def fallback_text : String?
    @message.try(&.fallback_text) || @text
  end

  def validate(prefix : String) : Array(Slack::UI::ValidationIssue)
    issues = @message.try(&.validate) || [] of Slack::UI::ValidationIssue
    text_issues(issues, prefix)
    attachment_issues(issues, prefix)
    issues
  end

  # Writes `text`, `blocks`, `markdown_text`, and `attachments` when present.
  def fields(json : JSON::Builder) : Nil
    if message = @message
      json.field "text", message.fallback_text if message.fallback_text
      json.field("blocks") { message.blocks_to_json(json) }
    end
    json.field "text", @text if @text
    json.field "markdown_text", @markdown_text if @markdown_text
    json.field "attachments", @attachments if @attachments
  end

  private def text_issues(issues : Array(Slack::UI::ValidationIssue), prefix : String) : Nil
    if @text.try(&.empty?)
      issues << Slack::UI::ValidationIssue.new("#{prefix}.text.empty", "text", "Text must not be empty.")
    end
    return unless markdown_text = @markdown_text

    if markdown_text.empty?
      issues << Slack::UI::ValidationIssue.new(
        "#{prefix}.markdown_text.empty", "markdown_text", "Markdown text must not be empty.")
    elsif markdown_text.size > MARKDOWN_TEXT_MAX_SIZE
      issues << Slack::UI::ValidationIssue.new(
        "#{prefix}.markdown_text.too_long", "markdown_text",
        "Markdown text cannot exceed #{MARKDOWN_TEXT_MAX_SIZE} characters.")
    end
  end

  private def attachment_issues(issues : Array(Slack::UI::ValidationIssue), prefix : String) : Nil
    return unless attachments = @attachments

    if attachments.size > ATTACHMENTS_MAX_SIZE
      issues << Slack::UI::ValidationIssue.new(
        "#{prefix}.attachments.too_many", "attachments",
        "A message cannot contain more than #{ATTACHMENTS_MAX_SIZE} attachments.")
    end
    attachments.each_with_index do |attachment, index|
      issues.concat(attachment.validate.map(&.at("attachments[#{index}]")))
    end
    attached_block_issues(issues, prefix, attachments)
  end

  # Block IDs are unique in the whole message, and Slack limits the Markdown
  # block text of the whole payload. Each Message and Attachment checks its own
  # blocks; this checks what spans them, so no issue is reported twice.
  private def attached_block_issues(issues : Array(Slack::UI::ValidationIssue), prefix : String,
                                    attachments : Array(Slack::UI::Attachment)) : Nil
    groups = [] of {String, Array(Slack::UI::MessageBlock)}
    @message.try { |message| groups << {"", message.blocks} }
    attachments.each_with_index do |attachment, index|
      attachment.blocks.try { |blocks| groups << {"attachments[#{index}].", blocks} }
    end
    duplicate_block_id_issues(issues, prefix, groups)
    combined_markdown_issue(issues, prefix, groups)
  end

  private def duplicate_block_id_issues(issues : Array(Slack::UI::ValidationIssue), prefix : String,
                                        groups : Array({String, Array(Slack::UI::MessageBlock)})) : Nil
    earlier = Set(String).new
    groups.each do |path_prefix, blocks|
      current = Set(String).new
      block_ids(blocks, path_prefix) do |id, path|
        if earlier.includes?(id)
          issues << Slack::UI::ValidationIssue.new(
            "#{prefix}.block_id.duplicate", path, "Block IDs must be unique within a message and its attachments.")
        end
        current << id
      end
      earlier.concat(current)
    end
  end

  private def block_ids(blocks : Array(Slack::UI::MessageBlock), prefix : String, & : String, String ->) : Nil
    blocks.each_with_index do |block, index|
      block.block_id.try { |id| yield id, "#{prefix}blocks[#{index}].block_id" }
      next unless block.is_a?(Slack::UI::Blocks::Container)

      block.child_blocks.each_with_index do |child, position|
        child.block_id.try { |id| yield id, "#{prefix}blocks[#{index}].child_blocks[#{position}].block_id" }
      end
    end
  end

  private def combined_markdown_issue(issues : Array(Slack::UI::ValidationIssue), prefix : String,
                                      groups : Array({String, Array(Slack::UI::MessageBlock)})) : Nil
    sizes = groups.map { |_, blocks| blocks.sum { |block| block.is_a?(Slack::UI::Blocks::Markdown) ? block.text.size : 0 } }
    limit = Slack::UI::Blocks::Markdown::TEXT_MAX_SIZE
    # A single group over the limit already has its own message issue.
    return if sizes.sum <= limit || sizes.any? { |size| size > limit }

    issues << Slack::UI::ValidationIssue.new(
      "#{prefix}.markdown.too_long", "attachments",
      "The markdown blocks in a message and its attachments cannot contain more than #{limit} characters in total.")
  end
end
