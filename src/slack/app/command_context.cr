# The context of an `App#command` listener for a slash command.
struct Slack::App::CommandContext < Slack::App::Context
  include Acknowledging

  getter command : Slack::Command

  def initialize(environment : Environment, @command : Slack::Command)
    super(environment)
  end

  # Acknowledges with *response* as the first message. Raises
  # `UI::ValidationError` for an invalid response and `AlreadyAcknowledged`
  # when the request already has a response.
  def ack(response : Slack::Commands::Response) : Nil
    acknowledge(response)
  end
end
