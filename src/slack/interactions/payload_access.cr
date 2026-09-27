# Runtime shape checks for external JSON, separate from outbound validation.
module Slack::Interactions::PayloadAccess
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
end
