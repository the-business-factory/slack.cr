require "json"
require "./type_mismatch"

# :nodoc:
#
# Runtime shape checks for external JSON, separate from outbound validation.
# Each check raises `Slack::TypeMismatch` with the field path.
module Slack::PayloadAccess
  def self.object?(raw : JSON::Any?, path : String) : Hash(String, JSON::Any)?
    return if raw.nil? || raw.raw.nil?
    raw.as_h? || raise TypeMismatch.new(path, "object", raw.raw.class.to_s)
  end

  def self.string?(raw : JSON::Any?, path : String) : String?
    return if raw.nil? || raw.raw.nil?
    raw.as_s? || raise TypeMismatch.new(path, "string or null", raw.raw.class.to_s)
  end

  def self.string(raw : JSON::Any?, path : String) : String
    string?(raw, path) || raise TypeMismatch.new(path, "string", raw.nil? ? "absent" : "null")
  end

  def self.bool?(raw : JSON::Any?, path : String) : Bool?
    return if raw.nil? || raw.raw.nil?
    value = raw.as_bool?
    raise TypeMismatch.new(path, "bool or null", raw.raw.class.to_s) if value.nil?
    value
  end

  def self.int64?(raw : JSON::Any?, path : String) : Int64?
    return if raw.nil? || raw.raw.nil?
    return raw.as_i64 if raw.raw.is_a?(Int64)
    raise TypeMismatch.new(path, "integer or null", raw.raw.class.to_s)
  end

  def self.int64(raw : JSON::Any?, path : String) : Int64
    return raw.as_i64 if raw && raw.raw.is_a?(Int64)
    raise TypeMismatch.new(path, "integer", raw.nil? ? "absent" : raw.raw.class.to_s)
  end
end
