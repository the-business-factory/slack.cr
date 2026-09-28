# :nodoc:
# Reads received rich text JSON by tree position without outbound rules.
# Unknown node types stay opaque. A known type in the wrong position is malformed.
module Slack::Interactions::RichText::Decoder
  CONTAINER_TYPES = {"rich_text_section", "rich_text_list", "rich_text_preformatted", "rich_text_quote"}
  ELEMENT_TYPES   = {"text", "link", "emoji", "user", "usergroup", "channel", "broadcast", "date", "color"}

  def self.object(raw : JSON::Any, path : String) : Hash(String, JSON::Any)
    PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "rich text object", "null")
  end

  def self.containers(object : Hash(String, JSON::Any), path : String) : Array(Container)
    items(object, path).map_with_index { |item, index| container(item, "#{path}.elements[#{index}]") }
  end

  def self.elements(object : Hash(String, JSON::Any), path : String) : Array(Element)
    items(object, path).map_with_index { |item, index| element(item, "#{path}.elements[#{index}]") }
  end

  # Slack documents rich_text_section as the only list item type.
  def self.sections(object : Hash(String, JSON::Any), path : String) : Array(Section)
    items(object, path).map_with_index do |item, index|
      item_path = "#{path}.elements[#{index}]"
      type = type(object(item, item_path), item_path)
      raise TypeMismatch.new("#{item_path}.type", "rich_text_section", type) unless type == "rich_text_section"
      Section.new(item, item_path)
    end
  end

  def self.style?(object : Hash(String, JSON::Any), path : String) : Style?
    raw = object["style"]?
    Style.new(raw, "#{path}.style") if raw && !raw.raw.nil?
  end

  def self.bool?(raw : JSON::Any?, path : String) : Bool?
    return if raw.nil? || raw.raw.nil?
    value = raw.as_bool?
    value.nil? ? raise TypeMismatch.new(path, "boolean or null", raw.raw.class.to_s) : value
  end

  def self.int32?(raw : JSON::Any?, path : String) : Int32?
    return if raw.nil? || raw.raw.nil?
    raw.as_i? || raise TypeMismatch.new(path, "integer or null", raw.raw.class.to_s)
  end

  def self.int64(raw : JSON::Any?, path : String) : Int64
    raw.try(&.as_i64?) || raise TypeMismatch.new(path, "integer", raw.nil? ? "absent" : raw.raw.class.to_s)
  end

  private def self.container(raw : JSON::Any, path : String) : Container
    type = type(object(raw, path), path)
    case type
    when "rich_text_section"      then Section.new(raw, path)
    when "rich_text_list"         then List.new(raw, path)
    when "rich_text_preformatted" then Preformatted.new(raw, path)
    when "rich_text_quote"        then Quote.new(raw, path)
    else
      raise TypeMismatch.new("#{path}.type", "rich text container", type) if ELEMENT_TYPES.includes?(type)
      Unknown.new(type, raw)
    end
  end

  private def self.element(raw : JSON::Any, path : String) : Element
    type = type(object(raw, path), path)
    case type
    when "text"      then Text.new(raw, path)
    when "link"      then Link.new(raw, path)
    when "emoji"     then Emoji.new(raw, path)
    when "user"      then User.new(raw, path)
    when "usergroup" then Usergroup.new(raw, path)
    when "channel"   then Channel.new(raw, path)
    when "broadcast" then Broadcast.new(raw, path)
    when "date"      then Date.new(raw, path)
    when "color"     then Color.new(raw, path)
    else
      raise TypeMismatch.new("#{path}.type", "rich text element", type) if CONTAINER_TYPES.includes?(type)
      Unknown.new(type, raw)
    end
  end

  private def self.type(object : Hash(String, JSON::Any), path : String) : String
    PayloadAccess.string(object["type"]?, "#{path}.type")
  end

  private def self.items(object : Hash(String, JSON::Any), path : String) : Array(JSON::Any)
    raw = object["elements"]?
    raw.try(&.as_a?) || raise TypeMismatch.new("#{path}.elements", "array", raw.nil? ? "absent" : raw.raw.class.to_s)
  end
end
