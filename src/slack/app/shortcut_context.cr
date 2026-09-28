# The context of an `App#shortcut` listener for a global or message shortcut.
struct Slack::App::ShortcutContext < Slack::App::Context
  include Acknowledging
  include Saying
  include Responding

  getter shortcut : Slack::Interactions::Shortcut | Slack::Interactions::MessageAction

  def initialize(environment : Environment,
                 @shortcut : Slack::Interactions::Shortcut | Slack::Interactions::MessageAction)
    super(environment)
  end

  # A message shortcut names its channel; a global shortcut does not.
  private def say_channel : String?
    @shortcut.channel.try(&.id)
  end

  private def response_url : String?
    shortcut = @shortcut
    shortcut.response_url if shortcut.is_a?(Slack::Interactions::MessageAction)
  end
end
