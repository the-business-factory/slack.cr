# Slack sends the entered text as a `rich_text` block. The tree is read with
# the received rich text parser, without outbound rules.
struct Slack::Interactions::RichTextInputValue
  getter raw : JSON::Any
  getter rich_text_value : RichText::Block?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "rich_text_input object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "rich_text_input"
      raise TypeMismatch.new("#{path}.type", "rich_text_input", actual || "absent or null")
    end
    tree = object["rich_text_value"]?
    @rich_text_value = RichText::Block.new(tree, "#{path}.rich_text_value") if tree && !tree.raw.nil?
  end

  def type : String
    "rich_text_input"
  end

  def value_presence : ValuePresence
    ValuePresence.of(@raw["rich_text_value"]?)
  end
end
