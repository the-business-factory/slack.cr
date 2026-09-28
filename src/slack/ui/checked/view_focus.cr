# A view has one focus target across Input, Actions, and Section children.
module Slack::UI::Checked::ViewFocus
  def self.validate(blocks : Enumerable(T), surface : String) : Array(ValidationIssue) forall T
    issues = [] of ValidationIssue
    focused = false
    blocks.each_with_index do |block, index|
      paths(block).each do |path|
        if focused
          issues << ValidationIssue.new("#{surface}.focus_on_load.duplicate", "blocks[#{index}].#{path}", "Only one element in a view can focus on load.")
        end
        focused = true
      end
    end
    issues
  end

  private def self.paths(block : HomeBlock) : Array(String)
    paths = [] of String
    case block
    when Blocks::Input
      paths << "element.focus_on_load" if block.element.focus_on_load
    when Blocks::Section
      if focused?(block.accessory)
        paths << "accessory.focus_on_load"
      end
    when Blocks::Actions
      block.elements.each_with_index do |element, index|
        paths << "elements[#{index}].focus_on_load" if focused?(element)
      end
    end
    paths
  end

  private def self.focused?(element : Blocks::Section::Accessory?) : Bool
    case element
    when BlockElements::DatePicker, BlockElements::TimePicker, BlockElements::StaticSelect, BlockElements::MultiStaticSelect, BlockElements::Checkboxes, BlockElements::RadioButtons, BlockElements::UsersSelect, BlockElements::MultiUsersSelect, BlockElements::ConversationsSelect, BlockElements::MultiConversationsSelect, BlockElements::ChannelsSelect, BlockElements::MultiChannelsSelect
      element.focus_on_load == true
    else
      false
    end
  end
end
