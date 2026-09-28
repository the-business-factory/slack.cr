# The item of a `reaction_added` or `reaction_removed` event, decoded by
# `type`. An item type that this library does not model decodes as
# `ReactionItem::Unknown`. Every variant keeps its raw JSON, and `to_json`
# writes it unchanged. A known item with a missing or malformed field raises
# `JSON::ParseException` while the event decodes.
# https://docs.slack.dev/reference/events/reaction_added
abstract struct Slack::EventData::ReactionItem
  getter raw : JSON::Any

  def self.new(pull : JSON::PullParser) : ReactionItem
    line, column = pull.location
    raw = JSON::Any.new(pull)
    object = raw.as_h? || raise JSON::ParseException.new("Expected an object for a reaction item", line, column)
    fields = Fields.new(object, line, column)
    case type = fields.string?("type")
    when "message"      then Message.new(raw, fields)
    when "file"         then File.new(raw, fields)
    when "file_comment" then FileComment.new(raw, fields)
    else                     Unknown.new(type, raw)
    end
  end

  def initialize(@raw : JSON::Any)
  end

  def to_json(json : JSON::Builder) : Nil
    @raw.to_json(json)
  end

  # :nodoc:
  # Reads string fields of an item object and reports a bad shape at the item's location.
  struct Fields
    def initialize(@object : Hash(String, JSON::Any), @line : Int32, @column : Int32)
    end

    def string?(key : String) : String?
      value = @object[key]?
      return if value.nil? || value.raw.nil?
      value.as_s? || raise JSON::ParseException.new("Expected a string or null for reaction item #{key}", @line, @column)
    end

    def string(key : String) : String
      string?(key) || raise JSON::ParseException.new("Missing reaction item #{key}", @line, @column)
    end
  end

  # A reaction to a message.
  struct Message < ReactionItem
    getter channel : String
    getter ts : String

    # For example `channel` or `im`. Not every example payload carries it.
    getter channel_type : String?

    def initialize(raw : JSON::Any, fields : Fields)
      super(raw)
      @channel = fields.string("channel")
      @ts = fields.string("ts")
      @channel_type = fields.string?("channel_type")
    end

    def type : String
      "message"
    end
  end

  # A reaction to a file.
  struct File < ReactionItem
    getter file : String

    def initialize(raw : JSON::Any, fields : Fields)
      super(raw)
      @file = fields.string("file")
    end

    def type : String
      "file"
    end
  end

  # A reaction to a comment on a file.
  struct FileComment < ReactionItem
    getter file : String
    getter file_comment : String

    def initialize(raw : JSON::Any, fields : Fields)
      super(raw)
      @file = fields.string("file")
      @file_comment = fields.string("file_comment")
    end

    def type : String
      "file_comment"
    end
  end

  # An item type that this library does not model. `type` is nil when absent or null.
  struct Unknown < ReactionItem
    getter type : String?

    def initialize(@type : String?, raw : JSON::Any)
      super(raw)
    end
  end
end
