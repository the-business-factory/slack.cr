class Slack::Errors::ReplayAttack < Exception
  def initialize
    super("Replay attack detected")
  end
end
