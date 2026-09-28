# The context of an `App#command` listener for a slash command.
struct Slack::App::CommandContext < Slack::App::Context
  include Acknowledging
  include Saying
  include Responding

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

  private def say_channel : String?
    @command.channel_id
  end

  private def response_url : String?
    @command.response_url
  end
end
