struct Slack::Interactions::MultiUsersSelectValue
  getter raw : JSON::Any
  @selected_users : Array(String)?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "multi_users_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "multi_users_select"
      raise TypeMismatch.new("#{path}.type", "multi_users_select", actual || "absent or null")
    end
    selection = object["selected_users"]?
    @selected_users = if selection && !selection.raw.nil?
                        items = selection.as_a? || raise TypeMismatch.new("#{path}.selected_users", "array or null", selection.raw.class.to_s)
                        items.map_with_index { |item, index| PayloadAccess.string(item, "#{path}.selected_users[#{index}]") }
                      end
  end

  def type : String
    "multi_users_select"
  end

  def selected_users_presence : ValuePresence
    ValuePresence.of(@raw["selected_users"]?)
  end

  def selected_users : Array(String)?
    @selected_users.try(&.dup)
  end
end
