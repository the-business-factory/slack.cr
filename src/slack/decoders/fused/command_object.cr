# :nodoc:
# Lets `FusedJSON.from_json` decode a slash command JSON object with the
# rules of `Slack::Commands::Parser.from_json_object`.
struct Slack::Decoders::Fused::CommandObject
  getter command : Slack::Command

  def initialize(@command : Slack::Command)
  end

  def self.new(pull : JSON::PullParser) : self
    new(Slack::Commands::Parser.from_json_object(pull))
  end
end
