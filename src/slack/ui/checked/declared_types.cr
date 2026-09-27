# :nodoc:
# Keeps the display/form remedy at the copied-value boundary.
module Slack::UI::Checked::DeclaredTypes
  def self.display_modal_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::DisplayModalBlock %}
      {% raise "DisplayModal rejects its yielded block item type. For Input, use FormModal with submit." %}
    {% end %}
  end
end
