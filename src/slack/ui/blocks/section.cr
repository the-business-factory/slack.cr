# https://api.slack.com/reference/block-kit/blocks#section
#
# Slack Section Blocks have several behavioral differences based on whether the
# content of the section is a single text block or multiple blocks.
struct Slack::UI::Blocks::Section < Slack::UI::Block
  text_object Text, max_length: 3000
  text_object FieldText, max_length: 2000

  # Defines validations that prevent Sections from being created:
  # - Some form of text is required
  # - Arrays of text can only have 10 text objects.
  def after_initialize : Nil
    if @text.nil? && @fields.nil?
      raise Slack::Errors::InvalidUIBlock.new("Text or Fields must be present")
    end

    if @fields.try(&.empty?)
      raise Slack::Errors::InvalidUIBlock.new(
        "Fields must have at least one text object"
      )
    end

    if @fields.try &.size.>(10)
      raise Slack::Errors::InvalidUIBlock.new(
        "Fields can include a max of 10 text objects"
      )
    end

    validate_block_id!
  end

  properties_with_initializer \
    accessory : BlockElement? = nil,
    block_id : String? = nil,
    type : String = "section",
    text : Text? = nil,
    fields : Array(FieldText)? = nil

  def to_json(json : JSON::Builder) : Nil
    validate_block_id!

    json.object do
      json.field "type", type
      json.field "text", text unless text.nil?
      json.field "fields", fields unless fields.nil?
      json.field "accessory", accessory unless accessory.nil?
      json.field "block_id", block_id unless block_id.nil?
    end
  end

  private def validate_block_id! : Nil
    if @block_id.try &.size.>(255)
      raise Slack::Errors::InvalidUIBlock.new(
        "Block ID cannot be longer than 255 characters"
      )
    end
  end
end
