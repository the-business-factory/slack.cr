# The context of an `App#view` listener for a `view_submission` payload.
# An empty `ack` closes the submitted view.
struct Slack::App::ViewContext < Slack::App::Context
  include Acknowledging
  include FunctionInteractivity

  getter payload : Slack::Interactions::ViewSubmission

  def initialize(environment : Environment, @payload : Slack::Interactions::ViewSubmission)
    super(environment)
  end

  # Acknowledges with a response action: input errors, push, update, or clear.
  # Raises `UI::ValidationError` for an invalid view and `AlreadyAcknowledged`
  # when the request already has a response.
  def ack(response : Slack::Interactions::ModalErrors | Slack::Interactions::ModalPush |
                     Slack::Interactions::ModalUpdate | Slack::Interactions::ModalClear) : Nil
    acknowledge(response)
  end
end
