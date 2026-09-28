# :nodoc:
# Slack documents workflow_button for messages only. View surfaces use this
# check for Section accessories and Actions elements.
module Slack::UI::Checked::WorkflowButtonPlacement
  def self.validate(blocks : Enumerable(T), surface : String) : Array(ValidationIssue) forall T
    issues = [] of ValidationIssue
    blocks.each_with_index do |block, index|
      case block
      when Blocks::Section
        issues << issue(surface, "blocks[#{index}].accessory") if block.accessory.is_a?(BlockElements::WorkflowButton)
      when Blocks::Actions
        block.elements.each_with_index do |element, position|
          issues << issue(surface, "blocks[#{index}].elements[#{position}]") if element.is_a?(BlockElements::WorkflowButton)
        end
      end
    end
    issues
  end

  private def self.issue(surface : String, path : String) : ValidationIssue
    ValidationIssue.new("#{surface}.workflow_button.unsupported_surface", path, "Slack supports workflow_button only in messages.")
  end
end
