# Empty objects, arrays, and strings are Present, not Absent or Null.
enum Slack::Interactions::ValuePresence
  Absent
  Null
  Present

  def self.of(raw : JSON::Any?) : ValuePresence
    return Absent if raw.nil?
    raw.raw.nil? ? Null : Present
  end
end
