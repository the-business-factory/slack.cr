require "../../../support/block_kit/ui_only"

class BroadBlocks
  alias Section = Slack::UI::Checked::Proof::Section
  alias Forbidden = Slack::UI::Checked::Proof::Input(Slack::UI::Checked::Proof::SyntheticForbiddenInput)

  include Enumerable(Section | Forbidden)

  def initialize(@section : Section)
  end

  # This narrower yield is the compiler counterexample from the approved review.
  def each(&) : Nil
    yield @section
  end
end

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Title")
section = Slack::UI::Checked::Blocks::Section.new(text: plain)
builder = Slack::UI::Checked::Proof::FormModalBuilder.new(title: plain, submit: plain)
builder.add_all(BroadBlocks.new(section))
