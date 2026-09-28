# :nodoc:
# One registered listener. The match block returns the typed context when the
# payload matches, or nil.
abstract class Slack::App::Route
  abstract def listener(payload : App::Payload, environment : Environment) : Listener?
end
