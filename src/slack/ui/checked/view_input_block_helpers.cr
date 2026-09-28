# :nodoc:
# Included only by builders whose surfaces accept view-only input blocks.
module Slack::UI::Checked::ViewInputBlockHelpers
  def input(
    label : CompositionObjects::PlainText,
    element : Blocks::ViewInputElement,
    block_id : String? = nil,
    hint : CompositionObjects::PlainText? = nil,
    optional : Bool? = nil,
    dispatch_action : Bool? = nil,
  ) : Nil
    add(Blocks::ViewInput.new(label: label, element: element, block_id: block_id, hint: hint, optional: optional, dispatch_action: dispatch_action))
  end
end
