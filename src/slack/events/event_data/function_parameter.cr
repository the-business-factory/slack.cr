# One input or output parameter of a custom function, as its app manifest defines it.
struct Slack::Events::FunctionParameter
  include JSON::Serializable

  # A Slack type, such as `string` or `slack#/types/user_id`.
  getter type : String
  getter name : String

  @[JSON::Field(emit_null: false)]
  getter title : String?

  @[JSON::Field(emit_null: false)]
  getter description : String?

  # False when the manifest omits `is_required`.
  @[JSON::Field(key: "is_required")]
  getter? required : Bool = false
end
