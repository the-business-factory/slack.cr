# Raised by `say` when the payload has no channel, and by `respond` when it
# has no `response_url`. For example, a click in a modal has neither.
class Slack::App::NoReplyTarget < Exception
end
