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
  def after_initialize
    if @text.nil? && @fields.nil?
      raise Slack::Errors::InvalidUIBlock.new("Text or Fields must be present")
    end

    if @fields.try &.size.>(10)
      raise Slack::Errors::InvalidUIBlock.new(
        "Fields can include a max of 10 text objects"
      )
    end
  end

  properties_with_initializer \
    accessory : BlockElement?,
    block_id : String?,
    type : String = "section",
    text : Text?,
    fields : Array(FieldText)?

  def to_json(json : JSON::Builder)
    json.object do
      json.field "type", type
      json.field "text", text unless text.nil?
      json.field "fields", fields unless fields.nil?
      json.field "accessory", accessory unless accessory.nil?
    end
  end
end
