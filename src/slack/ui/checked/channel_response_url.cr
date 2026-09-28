# :nodoc:
# A supplied response_url_enabled field is supported only in modal Input blocks.
module Slack::UI::Checked::ChannelResponseUrl
  def self.validate(element : T, path : String) : Array(ValidationIssue) forall T
    issues = [] of ValidationIssue
    if element.is_a?(BlockElements::ChannelsSelect) && !element.response_url_enabled.nil?
      issues << ValidationIssue.new("channels_select.response_url_enabled.unsupported_placement", path,
        "response_url_enabled must be omitted outside an Input block in a modal.")
    end
    issues
  end

  def self.non_modal_inputs(blocks : Enumerable(T)) : Array(ValidationIssue) forall T
    issues = [] of ValidationIssue
    blocks.each_with_index do |block, index|
      if block.is_a?(Blocks::Input)
        issues.concat(validate(block.element, "blocks[#{index}].element.response_url_enabled"))
      end
    end
    issues
  end
end
