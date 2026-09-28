# :nodoc:
# Slack documents workflow_button for messages only. View surfaces use this
# check for Section accessories and Actions elements, including those in
# container child blocks.
module Slack::UI::Checked::WorkflowButtonPlacement
  def self.validate(blocks : Enumerable(T), surface : String) : Array(ValidationIssue) forall T
    issues = [] of ValidationIssue
    blocks.each_with_index do |block, index|
      block_issues(issues, block, surface, "blocks[#{index}]")
    end
    issues
  end

  private def self.block_issues(issues : Array(ValidationIssue), block : T, surface : String, path : String) : Nil forall T
    case block
    when Blocks::Section
      issues << issue(surface, "#{path}.accessory") if block.accessory.is_a?(BlockElements::WorkflowButton)
    when Blocks::Actions
      block.elements.each_with_index do |element, position|
        issues << issue(surface, "#{path}.elements[#{position}]") if element.is_a?(BlockElements::WorkflowButton)
      end
    when Blocks::Container
      block.child_blocks.each_with_index do |child, position|
        block_issues(issues, child, surface, "#{path}.child_blocks[#{position}]")
      end
    end
  end

  private def self.issue(surface : String, path : String) : ValidationIssue
    ValidationIssue.new("#{surface}.workflow_button.unsupported_surface", path, "Slack supports workflow_button only in messages.")
  end
end
