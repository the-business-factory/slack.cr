# :nodoc:
# Reads received block fields by position. Missing required fields and wrong JSON
# types raise `TypeMismatch` with the failing path. No outbound rules apply.
module Slack::Interactions::ReceivedBlocks::Decoder
  TEXT_TYPES = {"plain_text", "mrkdwn"}

  def self.block(raw : JSON::Any, path : String) : ReceivedBlock
    object = object(raw, path)
    type = PayloadAccess.string(object["type"]?, "#{path}.type")
    layout(type, object, path) || display(type, raw, object, path) || UnknownBlock.new(type, raw)
  end

  def self.object(raw : JSON::Any, path : String) : Hash(String, JSON::Any)
    PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "object", "null")
  end

  def self.block_id(object : Hash(String, JSON::Any), path : String) : String?
    PayloadAccess.string?(object["block_id"]?, "#{path}.block_id")
  end

  def self.items(object : Hash(String, JSON::Any), key : String, path : String) : Array(JSON::Any)
    raw = object[key]?
    raw.try(&.as_a?) || raise TypeMismatch.new("#{path}.#{key}", "array", actual(raw))
  end

  def self.text(object : Hash(String, JSON::Any), key : String, path : String) : ReceivedText
    text?(object, key, path) || raise TypeMismatch.new("#{path}.#{key}", "text object", actual(object[key]?))
  end

  def self.text?(object : Hash(String, JSON::Any), key : String, path : String) : ReceivedText?
    raw = object[key]?
    ReceivedText.new(raw, "#{path}.#{key}") if raw && !raw.raw.nil?
  end

  def self.texts(object : Hash(String, JSON::Any), key : String, path : String) : Array(ReceivedText)
    return [] of ReceivedText if absent?(object, key)
    items(object, key, path).map_with_index { |item, index| ReceivedText.new(item, "#{path}.#{key}[#{index}]") }
  end

  def self.element(object : Hash(String, JSON::Any), key : String, path : String) : ElementSummary
    element?(object, key, path) || raise TypeMismatch.new("#{path}.#{key}", "element object", actual(object[key]?))
  end

  def self.element?(object : Hash(String, JSON::Any), key : String, path : String) : ElementSummary?
    raw = object[key]?
    ElementSummary.new(raw, "#{path}.#{key}") if raw && !raw.raw.nil?
  end

  def self.elements(object : Hash(String, JSON::Any), key : String, path : String, *, required : Bool = true) : Array(ElementSummary)
    return [] of ElementSummary if !required && absent?(object, key)
    items(object, key, path).map_with_index { |item, index| ElementSummary.new(item, "#{path}.#{key}[#{index}]") }
  end

  def self.slack_icon?(object : Hash(String, JSON::Any), key : String, path : String) : SlackIcon?
    raw = object[key]?
    SlackIcon.new(raw, "#{path}.#{key}") if raw && !raw.raw.nil?
  end

  def self.sources(object : Hash(String, JSON::Any), path : String) : Array(TaskCard::Source)
    return [] of TaskCard::Source if absent?(object, "sources")
    items(object, "sources", path).map_with_index { |item, index| TaskCard::Source.new(item, "#{path}.sources[#{index}]") }
  end

  def self.blocks(object : Hash(String, JSON::Any), key : String, path : String) : Array(ReceivedBlock)
    items(object, key, path).map_with_index { |item, index| block(item, "#{path}.#{key}[#{index}]") }
  end

  def self.rich_text?(object : Hash(String, JSON::Any), key : String, path : String) : RichText::Block?
    raw = object[key]?
    RichText::Block.new(raw, "#{path}.#{key}") if raw && !raw.raw.nil?
  end

  def self.rows(object : Hash(String, JSON::Any), path : String) : Array(Array(TableCell))
    items(object, "rows", path).map_with_index do |row, row_index|
      row_path = "#{path}.rows[#{row_index}]"
      cells = row.as_a? || raise TypeMismatch.new(row_path, "array", actual(row))
      cells.map_with_index { |cell, index| table_cell(cell, "#{row_path}[#{index}]") }
    end
  end

  def self.string(object : Hash(String, JSON::Any), key : String, path : String) : String
    PayloadAccess.string(object[key]?, "#{path}.#{key}")
  end

  def self.string?(object : Hash(String, JSON::Any), key : String, path : String) : String?
    PayloadAccess.string?(object[key]?, "#{path}.#{key}")
  end

  def self.bool?(object : Hash(String, JSON::Any), key : String, path : String) : Bool?
    PayloadAccess.bool?(object[key]?, "#{path}.#{key}")
  end

  def self.int32?(object : Hash(String, JSON::Any), key : String, path : String) : Int32?
    raw = object[key]?
    return if raw.nil? || raw.raw.nil?
    raw.as_i? || raise TypeMismatch.new("#{path}.#{key}", "integer or null", actual(raw))
  end

  def self.number(object : Hash(String, JSON::Any), key : String, path : String) : Int64 | Float64
    raw = object[key]?
    value = raw.try(&.raw)
    return value if value.is_a?(Int64) || value.is_a?(Float64)
    raise TypeMismatch.new("#{path}.#{key}", "number", actual(raw))
  end

  # A required field that stays raw JSON, such as a chart.
  def self.raw(object : Hash(String, JSON::Any), key : String, path : String) : JSON::Any
    raw = object[key]?
    return raw if raw && !raw.raw.nil?
    raise TypeMismatch.new("#{path}.#{key}", "JSON value", actual(raw))
  end

  def self.raw?(object : Hash(String, JSON::Any), key : String) : JSON::Any?
    raw = object[key]?
    raw unless raw.nil? || raw.raw.nil?
  end

  def self.context_element(raw : JSON::Any, path : String) : ContextElement
    type = PayloadAccess.string(object(raw, path)["type"]?, "#{path}.type")
    TEXT_TYPES.includes?(type) ? ReceivedText.new(raw, path) : ElementSummary.new(raw, path)
  end

  private def self.layout(type : String, object : Hash(String, JSON::Any), path : String) : ReceivedBlock?
    case type
    when "section"         then Section.new(object, path)
    when "actions"         then Actions.new(object, path)
    when "context"         then Context.new(object, path)
    when "context_actions" then ContextActions.new(object, path)
    when "divider"         then Divider.new(object, path)
    when "header"          then Header.new(object, path)
    when "input"           then Input.new(object, path)
    when "container"       then Container.new(object, path)
    when "carousel"        then Carousel.new(object, path)
    when "card"            then Card.new(object, path)
    end
  end

  private def self.display(type : String, raw : JSON::Any, object : Hash(String, JSON::Any), path : String) : ReceivedBlock?
    case type
    when "rich_text"          then RichText::Block.new(raw, path)
    when "image"              then Image.new(object, path)
    when "markdown"           then Markdown.new(object, path)
    when "file"               then File.new(object, path)
    when "video"              then Video.new(object, path)
    when "table"              then Table.new(object, path)
    when "data_table"         then DataTable.new(object, path)
    when "alert"              then Alert.new(object, path)
    when "data_visualization" then DataVisualization.new(object, path)
    when "plan"               then Plan.new(object, path)
    when "task_card"          then TaskCard.new(object, path)
    end
  end

  private def self.table_cell(raw : JSON::Any, path : String) : TableCell
    object = object(raw, path)
    type = PayloadAccess.string(object["type"]?, "#{path}.type")
    case type
    when "raw_text"   then RawText.new(object, path)
    when "raw_number" then RawNumber.new(object, path)
    when "rich_text"  then RichText::Block.new(raw, path)
    else                   UnknownBlock.new(type, raw)
    end
  end

  private def self.absent?(object : Hash(String, JSON::Any), key : String) : Bool
    raw = object[key]?
    raw.nil? || raw.raw.nil?
  end

  private def self.actual(raw : JSON::Any?) : String
    return "absent" if raw.nil?
    raw.raw.nil? ? "null" : raw.raw.class.to_s
  end
end
