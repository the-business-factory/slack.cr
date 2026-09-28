# The custom function that a `function_executed` event runs.
# https://docs.slack.dev/reference/events/function_executed
struct Slack::Events::FunctionDefinition
  include JSON::Serializable

  getter id : String
  # The function key in the app manifest `functions` object.
  getter callback_id : String
  getter title : String

  @[JSON::Field(emit_null: false)]
  getter description : String?

  getter type : String
  getter app_id : String
  getter input_parameters : Array(FunctionParameter) = [] of FunctionParameter
  getter output_parameters : Array(FunctionParameter) = [] of FunctionParameter

  @[JSON::Field(converter: Time::EpochConverter)]
  getter date_created : Time

  @[JSON::Field(converter: Time::EpochConverter)]
  getter date_updated : Time

  # Slack sends 0 for a function that is not deleted.
  @[JSON::Field(key: "date_deleted")]
  @date_deleted_epoch : Int64 = 0_i64

  # The deletion time, or nil when the function is not deleted.
  def date_deleted : Time?
    Time.unix(@date_deleted_epoch) unless @date_deleted_epoch.zero?
  end
end
