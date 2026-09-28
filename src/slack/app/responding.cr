# :nodoc:
# `respond` for contexts whose payload can carry a `response_url`. Each context
# gives the URL through `#response_url`.
module Slack::App::Responding
  # Posts *message* to the payload's `response_url` through the app's
  # `response_url_transport`, without a token. Slack accepts up to five posts
  # within 30 minutes of the payload.
  #
  # Raises `NoReplyTarget` when the payload has no `response_url`,
  # `Interactions::ResponseUrlError` for a non-2xx status, and
  # `Auth::ContractError` for an invalid URL or a transport failure.
  def respond(message : Slack::Interactions::ResponseUrlMessage) : Nil
    url = response_url || raise NoReplyTarget.new("The payload has no response_url for respond")
    Slack::Interactions::ResponseUrlResponder.new(url).post(@environment.response_url_transport, message)
  end

  private abstract def response_url : String?
end
