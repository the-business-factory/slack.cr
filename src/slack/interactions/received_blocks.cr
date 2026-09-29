alias Slack::Interactions::ReceivedBlock = Slack::Interactions::ReceivedBlocks::Section |
                                           Slack::Interactions::ReceivedBlocks::Actions |
                                           Slack::Interactions::ReceivedBlocks::Context |
                                           Slack::Interactions::ReceivedBlocks::Divider |
                                           Slack::Interactions::ReceivedBlocks::Header |
                                           Slack::Interactions::ReceivedBlocks::Image |
                                           Slack::Interactions::ReceivedBlocks::Input |
                                           Slack::Interactions::RichText::Block |
                                           Slack::Interactions::ReceivedBlocks::Markdown |
                                           Slack::Interactions::ReceivedBlocks::File |
                                           Slack::Interactions::ReceivedBlocks::Video |
                                           Slack::Interactions::ReceivedBlocks::Table |
                                           Slack::Interactions::ReceivedBlocks::DataTable |
                                           Slack::Interactions::ReceivedBlocks::Container |
                                           Slack::Interactions::ReceivedBlocks::Card |
                                           Slack::Interactions::ReceivedBlocks::Carousel |
                                           Slack::Interactions::ReceivedBlocks::Alert |
                                           Slack::Interactions::ReceivedBlocks::ContextActions |
                                           Slack::Interactions::ReceivedBlocks::DataVisualization |
                                           Slack::Interactions::ReceivedBlocks::Plan |
                                           Slack::Interactions::ReceivedBlocks::TaskCard |
                                           Slack::Interactions::ReceivedBlocks::UnknownBlock

# Reads Block Kit blocks that Slack sends in messages and views.
#
# Received blocks are read-only views of the payload. They do not apply outbound
# validation rules, because Slack can send blocks that are older or newer than
# the library's rules. A block type that this library does not read decodes as
# `UnknownBlock`, which keeps its `raw` JSON. The complete payload stays in the
# source message or view, and its `to_json` writes it back.
module Slack::Interactions::ReceivedBlocks
  # Returns an empty array for absent or null blocks. Raises `TypeMismatch` when
  # the blocks are not an array or a known block type has a malformed field.
  def self.decode(raw : JSON::Any?, path : String) : Array(ReceivedBlock)
    return [] of ReceivedBlock if raw.nil? || raw.raw.nil?
    items = raw.as_a? || raise TypeMismatch.new(path, "array", raw.raw.class.to_s)
    items.map_with_index { |item, index| Decoder.block(item, "#{path}[#{index}]") }
  end
end
