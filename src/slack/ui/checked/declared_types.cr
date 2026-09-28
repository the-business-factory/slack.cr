# :nodoc:
# Keeps the display/form remedy at the copied-value boundary.
module Slack::UI::Checked::DeclaredTypes
  def self.display_modal_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::DisplayModalBlock %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Checked::Blocks::File } %}
        {% raise "DisplayModal rejects File blocks. Slack shows remote file blocks in messages only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Checked::Blocks::Table } %}
        {% raise "DisplayModal rejects Table blocks. Slack shows table blocks in messages and Home tabs only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Checked::Blocks::Markdown } %}
        {% raise "DisplayModal rejects Markdown blocks. Slack shows markdown blocks in messages only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Checked::Blocks::ContextActions } %}
        {% raise "DisplayModal rejects ContextActions blocks. Slack shows context actions blocks in messages only." %}
      {% end %}
      {% raise "DisplayModal rejects its yielded block item type. For Input, use FormModal with submit." %}
    {% end %}
  end

  # Message and Home have no modal-only display blocks.
  def self.non_modal_block(type : T.class) : Nil forall T
    {% if T.union_types.any? { |member| member <= Slack::UI::Checked::Blocks::Alert } %}
      {% raise "Messages and Home tabs reject Alert blocks. Slack shows alert blocks in modals only; use DisplayModal or FormModal." %}
    {% end %}
  end
end
