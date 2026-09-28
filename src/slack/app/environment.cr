# :nodoc:
# Per-request values that every context shares.
record Slack::App::Environment,
  client : Slack::Api::Client,
  log : ::Log,
  delivery : Slack::Events::Delivery?,
  ack : Slack::App::Ack = Slack::App::Ack.new,
  store : Hash(String, String) = {} of String => String
