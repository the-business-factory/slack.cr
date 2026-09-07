class Slack::Errors::SignatureMismatch < Exception
  def initialize(message : String = "Slack webhook signature mismatch")
    super(message)
  end
end
