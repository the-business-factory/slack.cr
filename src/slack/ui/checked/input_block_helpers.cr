# :nodoc:
# Included only by builders whose surfaces accept input blocks.
module Slack::UI::Checked::InputBlockHelpers
  def input(
    label : CompositionObjects::PlainText,
    element : Blocks::InputElement,
    block_id : String? = nil,
    hint : CompositionObjects::PlainText? = nil,
    optional : Bool? = nil,
    dispatch_action : Bool? = nil,
  ) : Nil
    add(Blocks::Input.new(label: label, element: element, block_id: block_id, hint: hint, optional: optional, dispatch_action: dispatch_action))
  end
end
