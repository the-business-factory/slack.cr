class Slack::Errors::SignatureMismatch < Exception
  def initialize
    super("Slack webhook signature mismatch")
  end
end
