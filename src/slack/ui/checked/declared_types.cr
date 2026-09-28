# :nodoc:
# Keeps the display/form remedy at the copied-value boundary.
module Slack::UI::Checked::DeclaredTypes
  def self.display_modal_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::DisplayModalBlock %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Checked::Blocks::File } %}
        {% raise "DisplayModal rejects File blocks. Slack shows remote file blocks in messages only." %}
      {% end %}
      {% raise "DisplayModal rejects its yielded block item type. For Input, use FormModal with submit." %}
    {% end %}
  end
end
