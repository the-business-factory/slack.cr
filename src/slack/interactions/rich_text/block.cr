alias Slack::Interactions::RichText::Container = Slack::Interactions::RichText::Section |
                                                 Slack::Interactions::RichText::List |
                                                 Slack::Interactions::RichText::Preformatted |
                                                 Slack::Interactions::RichText::Quote |
                                                 Slack::Interactions::RichText::Unknown

# A received `rich_text` block, for example from a message event.
# Construction reads the whole tree and raises `TypeMismatch` for malformed nodes.
struct Slack::Interactions::RichText::Block
  getter block_id : String?
  @elements : Array(Container)

  def initialize(raw : JSON::Any, path : String = "rich_text")
    object = Decoder.object(raw, path)
    type = PayloadAccess.string?(object["type"]?, "#{path}.type")
    raise TypeMismatch.new("#{path}.type", "rich_text", type || "absent or null") unless type == "rich_text"
    @block_id = PayloadAccess.string?(object["block_id"]?, "#{path}.block_id")
    @elements = Decoder.containers(object, path)
  end

  def elements : Array(Container)
    @elements.dup
  end
end
