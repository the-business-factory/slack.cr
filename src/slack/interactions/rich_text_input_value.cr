# Slack sends the entered text as a `rich_text` block. The tree is read with
# the received rich text parser, without outbound rules.
struct Slack::Interactions::RichTextInputValue
  getter rich_text_value : RichText::Block?
  getter value_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "rich_text_input object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "rich_text_input"
      raise TypeMismatch.new("#{path}.type", "rich_text_input", actual || "absent or null")
    end
    tree = object["rich_text_value"]?
    @rich_text_value = RichText::Block.new(tree, "#{path}.rich_text_value") if tree && !tree.raw.nil?
    @value_presence = ValuePresence.of(object["rich_text_value"]?)
  end

  def type : String
    "rich_text_input"
  end
end
