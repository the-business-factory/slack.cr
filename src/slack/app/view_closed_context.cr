# The context of an `App#view_closed` listener. Slack sends `view_closed` only
# for views with `notify_on_close`.
struct Slack::App::ViewClosedContext < Slack::App::Context
  include Acknowledging

  getter payload : Slack::Interactions::ViewClosed

  def initialize(environment : Environment, @payload : Slack::Interactions::ViewClosed)
    super(environment)
  end
end
