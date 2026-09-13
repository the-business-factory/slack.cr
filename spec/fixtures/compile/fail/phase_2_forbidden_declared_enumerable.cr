require "../../../../src/slack/ui"

struct ForbiddenBlock
end

class BroadPhase2Blocks
  alias Section = Slack::UI::Checked::Blocks::Section

  include Enumerable(Section | ForbiddenBlock)

  def initialize(@section : Section)
  end

  # The implementation deliberately yields only the accepted member.
  def each(&) : Nil
    yield @section
  end
end

section = Slack::UI::Checked::Blocks::Section.new(
  text: Slack::UI::Checked.plain("Allowed value")
)
builder = Slack::UI::Checked::MessageBuilder.new(fallback_text: "Compile failure")
builder.add_all(BroadPhase2Blocks.new(section))
