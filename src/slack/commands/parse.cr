require "./parser"

module Slack::Commands
  # Decodes a verified slash command form body. See `Parser.parse` for the rules.
  # Pass only a body that `Slack::Webhooks::Verifier#verify` returned.
  def self.parse(body : String) : Slack::Command
    Parser.parse(body)
  end
end
