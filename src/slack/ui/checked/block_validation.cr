# :nodoc:
# Appends each block's issues before its duplicate-ID issues, in block order.
# Block IDs of container children share the surface's ID space.
module Slack::UI::Checked::BlockValidation
  def self.validate(
    blocks : Enumerable(T),
    issues : Array(ValidationIssue),
    duplicate_code : String,
    duplicate_message : String,
  ) : Nil forall T
    block_ids = Set(String).new
    blocks.each_with_index do |block, index|
      block.validate.each { |issue| issues << issue.at("blocks[#{index}]") }
      duplicate_id(block.block_id, block_ids, issues, "blocks[#{index}].block_id", duplicate_code, duplicate_message)
      next unless block.is_a?(Blocks::Container)

      block.child_blocks.each_with_index do |child, position|
        duplicate_id(child.block_id, block_ids, issues, "blocks[#{index}].child_blocks[#{position}].block_id", duplicate_code, duplicate_message)
      end
    end
  end

  private def self.duplicate_id(
    id : String?,
    block_ids : Set(String),
    issues : Array(ValidationIssue),
    path : String,
    duplicate_code : String,
    duplicate_message : String,
  ) : Nil
    return unless id
    return if block_ids.add?(id)

    issues << ValidationIssue.new(duplicate_code, path, duplicate_message)
  end
end
