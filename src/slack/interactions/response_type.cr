# Who sees a slash command response or a `response_url` message. Slack uses
# `Ephemeral` when a response omits `response_type`.
enum Slack::Interactions::ResponseType
  # Only the user who ran the command or used the component sees the message.
  Ephemeral
  # Everyone in the conversation sees the message. For a slash command, Slack
  # also shows the command that the user entered.
  InChannel

  def to_json(json : JSON::Builder) : Nil
    json.string(to_s.underscore)
  end
end
