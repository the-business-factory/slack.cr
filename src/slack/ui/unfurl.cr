# The Block Kit content of one link unfurl for `Slack::Api::ChatUnfurl`.
#
# Blocks follow the message block rules. *preview* sets the title and icon that
# the message composer shows; Slack ignores it outside the composer and builds a
# preview from the blocks when it is absent.
# See https://docs.slack.dev/messaging/unfurling-links-in-messages.
struct Slack::UI::Unfurl
  include Slack::UI::ValueValidation

  # A copy of the blocks, validated with the message block rules.
  @content : Message

  getter preview : Preview?

  def initialize(*, blocks : Enumerable(T), @preview : Preview? = nil) forall T
    @content = Message.with_slack_generated_fallback(blocks)
    validate!
  end

  def blocks : Array(MessageBlock)
    @content.blocks
  end

  def validate : Array(ValidationIssue)
    @content.validate
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field("blocks") { @content.blocks_to_json(json) }
      json.field "preview", @preview if @preview
    end
  end
end
