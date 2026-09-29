require "json"
require "../payload_access"

# Decodes one inbound Socket Mode text frame.
#
# ```
# case frame = Slack::SocketMode::Frame.parse(text)
# in Slack::SocketMode::Envelope     then handle(frame)
# in Slack::SocketMode::Hello        then ready(frame.num_connections)
# in Slack::SocketMode::Disconnect   then reconnect(frame.reason)
# in Slack::SocketMode::UnknownFrame then log(frame.type)
# end
# ```
#
# A frame with an `envelope_id` is an `Envelope`, also when its type is not
# documented, so that the app can acknowledge it. Malformed fields raise
# `Slack::TypeMismatch` with the field path.
module Slack::SocketMode::Frame
  def self.parse(text : String) : Hello | Disconnect | Envelope | UnknownFrame
    fields, payload_json = read_fields(text)
    type = Slack::PayloadAccess.string?(fields["type"]?, "type")
    case type
    when "hello"      then hello(fields)
    when "disconnect" then disconnect(fields)
    else
      if fields.has_key?("envelope_id")
        envelope(fields, payload_json)
      else
        UnknownFrame.new(type, JSON.parse(text))
      end
    end
  end

  # Keeps the payload as raw JSON so that payload decoders see the original
  # bytes, including duplicate keys.
  private def self.read_fields(text : String) : Tuple(Hash(String, JSON::Any), String?)
    fields = {} of String => JSON::Any
    payload_json = nil
    pull = JSON::PullParser.new(text)
    pull.read_object do |key|
      if key == "payload"
        payload_json = pull.read_raw
      else
        fields[key] = JSON::Any.new(pull)
      end
    end
    {fields, payload_json}
  end

  private def self.hello(fields : Hash(String, JSON::Any)) : Hello
    debug_info = Slack::PayloadAccess.object?(fields["debug_info"]?, "debug_info")
    connection_info = Slack::PayloadAccess.object?(fields["connection_info"]?, "connection_info")
    Hello.new(
      num_connections: integer?(fields["num_connections"]?, "num_connections") ||
                       raise(Slack::TypeMismatch.new("num_connections", "integer", "absent or null")),
      approximate_connection_time: integer?(debug_info.try(&.["approximate_connection_time"]?), "debug_info.approximate_connection_time"),
      app_id: Slack::PayloadAccess.string(connection_info.try(&.["app_id"]?), "connection_info.app_id"),
    )
  end

  private def self.disconnect(fields : Hash(String, JSON::Any)) : Disconnect
    Disconnect.new(
      Slack::PayloadAccess.string(fields["reason"]?, "reason"),
      fields["debug_info"]?,
    )
  end

  private def self.envelope(fields : Hash(String, JSON::Any), payload_json : String?) : Envelope
    envelope_id = Slack::PayloadAccess.string(fields["envelope_id"]?, "envelope_id")
    type = Slack::PayloadAccess.string(fields["type"]?, "type")
    payload = payload_json || raise Slack::TypeMismatch.new("payload", "JSON value", "absent")
    Envelope.new(
      envelope_id, type, payload,
      accepts_response_payload: boolean?(fields["accepts_response_payload"]?, "accepts_response_payload") || false,
      retry_attempt: integer?(fields["retry_attempt"]?, "retry_attempt"),
      retry_reason: Slack::PayloadAccess.string?(fields["retry_reason"]?, "retry_reason"),
    )
  end

  private def self.integer?(raw : JSON::Any?, path : String) : Int32?
    return if raw.nil? || raw.raw.nil?
    raw.as_i? || raise Slack::TypeMismatch.new(path, "integer or null", raw.raw.class.to_s)
  end

  private def self.boolean?(raw : JSON::Any?, path : String) : Bool?
    return if raw.nil? || raw.raw.nil?
    value = raw.raw
    value.is_a?(Bool) ? value : raise Slack::TypeMismatch.new(path, "boolean or null", value.class.to_s)
  end
end
