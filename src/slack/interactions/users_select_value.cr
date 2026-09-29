struct Slack::Interactions::UsersSelectValue
  getter selected_user : String?
  getter selected_user_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "users_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "users_select"
      raise TypeMismatch.new("#{path}.type", "users_select", actual || "absent or null")
    end
    selection = object["selected_user"]?
    @selected_user = PayloadAccess.string?(selection, "#{path}.selected_user")
    @selected_user_presence = ValuePresence.of(object["selected_user"]?)
  end

  def type : String
    "users_select"
  end
end
