# The context of an `App#options` listener for a `block_suggestion` payload.
struct Slack::App::OptionsContext < Slack::App::Context
  include Acknowledging

  getter payload : Slack::Interactions::BlockSuggestion

  def initialize(environment : Environment, @payload : Slack::Interactions::BlockSuggestion)
    super(environment)
  end

  # Acknowledges with the options to show. Raises `AlreadyAcknowledged` when
  # the request already has a response.
  def ack(response : Slack::Interactions::BlockSuggestionResponse) : Nil
    acknowledge(response)
  end
end
