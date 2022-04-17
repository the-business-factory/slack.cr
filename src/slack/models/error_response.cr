struct Slack::Models::ErrorResponse < Slack::Model
  properties_with_initializer \
    error : String,
    errors : Array(JSON::Any)?,
    ok : Bool = false,
    response_metadata : JSON::Any?

  def after_initialize
    raise Errors::Api.new(to_json) if @ok == false
  end
end
