# :nodoc:
# Appends each block's issues before its duplicate-ID issue, in block order.
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
      id = block.block_id
      next unless id
      next if block_ids.add?(id)

      issues << ValidationIssue.new(duplicate_code, "blocks[#{index}].block_id", duplicate_message)
    end
  end
end
