# :nodoc:
# The discriminators of a payload: the top-level `type`, and for an Events API
# body the `type` and `subtype` of its `event` object.
#
# `.scan` reads them with `FusedJSON::PullParser` and skips all other values.
# A discriminator that is absent or `null` is nil. A discriminator of another
# JSON type makes the scan irregular (`#regular?` is false); the decoder then
# uses the generic decode path, which reports the error.
struct Slack::Decoders::Fused::Discriminators
  getter type : String?
  getter event_type : String?
  getter subtype : String?
  getter? regular : Bool

  def initialize(@type : String?, @event_type : String?, @subtype : String?, @regular : Bool)
  end

  # Scans *body*. Raises `JSON::ParseException` when *body* is not one JSON
  # object.
  def self.scan(body : String) : self
    type = event_type = subtype = nil
    type_regular = event_regular = true
    pull = FusedJSON::PullParser.new(body)
    pull.read_object do |key|
      case key
      when "type"  then type, type_regular = read_discriminator(pull)
      when "event" then event_type, subtype, event_regular = read_event(pull)
      else              pull.skip
      end
    end
    pull.finish
    new(type, event_type, subtype, type_regular && event_regular)
  end

  # Reads the `type` and `subtype` of an `event` object. Skips a value of
  # another JSON type; the typed decode reports it.
  private def self.read_event(pull : FusedJSON::PullParser) : Tuple(String?, String?, Bool)
    unless pull.kind.begin_object?
      pull.skip
      return {nil, nil, true}
    end

    type = subtype = nil
    type_regular = subtype_regular = true
    pull.read_object do |key|
      case key
      when "type"    then type, type_regular = read_discriminator(pull)
      when "subtype" then subtype, subtype_regular = read_discriminator(pull)
      else                pull.skip
      end
    end
    {type, subtype, type_regular && subtype_regular}
  end

  # Reads a string or `null`. A value of another JSON type reads as nil and
  # is not regular.
  private def self.read_discriminator(pull : FusedJSON::PullParser) : Tuple(String?, Bool)
    return {pull.read_string, true} if pull.kind.string?

    regular = pull.kind.null?
    pull.skip
    {nil, regular}
  end
end
