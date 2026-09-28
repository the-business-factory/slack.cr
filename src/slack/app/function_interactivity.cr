# :nodoc:
# Function-scoped interactivity for contexts whose payload has `function_data`
# and `bot_access_token`: blocks and views that a custom step created.
module Slack::App::FunctionInteractivity
  # The custom step execution that created the block or view, with a client
  # that has the payload's workflow token. Nil when the payload has no
  # `function_data` or no `bot_access_token`. `#client` keeps the app client.
  #
  # ```
  # app.action("approve") do |ctx|
  #   ctx.ack
  #   ctx.function_execution.try(&.complete({approver: ctx.payload.user.try(&.id)}))
  # end
  # ```
  def function_execution : FunctionExecution?
    data = payload.function_data || return
    token = payload.bot_access_token || return
    FunctionExecution.new(data.execution_id, data.function.callback_id, data.inputs,
      @environment.workflow_client.call(token))
  end
end
