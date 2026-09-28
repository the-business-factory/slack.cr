# :nodoc:
# The empty acknowledgment for contexts whose listener must acknowledge.
module Slack::App::Acknowledging
  # Acknowledges the request with an empty HTTP 200. Raises
  # `AlreadyAcknowledged` when the request already has a response.
  def ack : Nil
    acknowledge(nil)
  end
end
