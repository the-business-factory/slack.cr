# :nodoc:
# Keeps the display/form remedy at the copied-value boundary.
module Slack::UI::DeclaredTypes
  def self.display_modal_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::DisplayModalBlock %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::File } %}
        {% raise "DisplayModal rejects File blocks. Slack shows remote file blocks in messages only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::Table } %}
        {% raise "DisplayModal rejects Table blocks. Slack shows table blocks in messages and Home tabs only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::Markdown } %}
        {% raise "DisplayModal rejects Markdown blocks. Slack shows markdown blocks in messages only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::ContextActions } %}
        {% raise "DisplayModal rejects ContextActions blocks. Slack shows context actions blocks in messages only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::DataTable } %}
        {% raise "DisplayModal rejects DataTable blocks. Slack shows data table blocks in messages and Home tabs only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::DataVisualization } %}
        {% raise "DisplayModal rejects DataVisualization blocks. Slack shows data visualization blocks in messages and Home tabs only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::Carousel } %}
        {% raise "DisplayModal rejects Carousel blocks. Slack shows carousels in messages and Home tabs only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::Container } %}
        {% raise "DisplayModal rejects Container blocks. Slack shows container blocks in messages and Home tabs only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::Plan } %}
        {% raise "DisplayModal rejects Plan blocks. Slack shows plan blocks in messages only." %}
      {% end %}
      {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::TaskCard } %}
        {% raise "DisplayModal rejects TaskCard blocks. Slack shows task card blocks in messages only." %}
      {% end %}
      {% raise "DisplayModal rejects its yielded block item type. For Input, use FormModal with submit." %}
    {% end %}
  end

  # Message and Home have no modal-only display blocks.
  def self.non_modal_block(type : T.class) : Nil forall T
    {% if T.union_types.any? { |member| member <= Slack::UI::Blocks::Alert } %}
      {% raise "Messages and Home tabs reject Alert blocks. Slack shows alert blocks in modals only; use DisplayModal or FormModal." %}
    {% end %}
  end
end
