# The custom function that owns an interactive block or view.
struct Slack::Interactions::FunctionRef
  include JSON::Serializable

  getter callback_id : String

  def initialize(@callback_id : String)
  end
end
