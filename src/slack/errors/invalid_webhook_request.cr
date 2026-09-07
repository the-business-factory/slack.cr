require "./signature_mismatch"

# Malformed signed-request inputs. Messages never include request data or secrets.
# Inherits SignatureMismatch so existing verification failure handlers still work.
class Slack::Errors::InvalidWebhookRequest < Slack::Errors::SignatureMismatch
  getter reason : Symbol

  def initialize(@reason : Symbol)
    super("Invalid Slack webhook request: #{reason}")
  end
end
