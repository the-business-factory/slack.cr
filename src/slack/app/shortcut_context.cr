# The context of an `App#shortcut` listener for a global or message shortcut.
struct Slack::App::ShortcutContext < Slack::App::Context
  include Acknowledging

  getter shortcut : Slack::Interactions::Shortcut | Slack::Interactions::MessageAction

  def initialize(environment : Environment,
                 @shortcut : Slack::Interactions::Shortcut | Slack::Interactions::MessageAction)
    super(environment)
  end
end
