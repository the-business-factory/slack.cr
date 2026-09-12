require "../../../support/block_kit/ui_only"

module Phase0CollectionPass
  alias Checked = Slack::UI::Checked
  alias Proof = Slack::UI::Checked::Proof

  class AllowedSections
    include Enumerable(Checked::Blocks::Section)

    def initialize(@section : Checked::Blocks::Section)
    end

    def each(&) : Nil
      yield @section
    end
  end

  class AllowedMixedBlocks
    include Enumerable(Proof::Section | Proof::Input(Proof::SyntheticCommonInput))

    def initialize(@section : Proof::Section)
    end

    # The implementation deliberately yields a narrower type than declared.
    def each(&) : Nil
      yield @section
    end
  end
end

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Title")
markdown = Slack::UI::Checked::CompositionObjects::Mrkdwn.new("*Summary*")
button = Slack::UI::Checked::BlockElements::Button.new(text: plain)
section = Slack::UI::Checked::Blocks::Section.new(text: markdown, accessory: button)
common = Slack::UI::Checked::Proof::Input.new(
  Slack::UI::Checked::Proof::SyntheticCommonInput.new("common")
)
modal = Slack::UI::Checked::Proof::Input.new(
  Slack::UI::Checked::Proof::SyntheticModalInput.new("modal")
)

homogeneous_array = [section]
homogeneous_tuple = {section, section}
mixed_array = [section, common]
mixed_tuple = {section, modal}

Slack::UI::Checked::Proof::DisplayModal.new(title: plain, blocks: homogeneous_array)
Slack::UI::Checked::Proof::DisplayModal.new(title: plain, blocks: homogeneous_tuple)
Slack::UI::Checked::Proof::FormModal.new(title: plain, submit: plain, blocks: mixed_array)
Slack::UI::Checked::Proof::FormModal.new(title: plain, submit: plain, blocks: mixed_tuple)
Slack::UI::Checked::Proof::FormModal.new(title: plain, submit: plain, blocks: [] of Slack::UI::Checked::Proof::Section)

normalized_element : Slack::UI::Checked::Proof::FormInputElement = Slack::UI::Checked::Proof::SyntheticCommonInput.new("normalized")
normalized = Slack::UI::Checked::Proof::Input(Slack::UI::Checked::Proof::FormInputElement)
  .new(normalized_element)
Slack::UI::Checked::Proof::FormModal.new(title: plain, submit: plain, blocks: [normalized])

builder = Slack::UI::Checked::Proof::FormModalBuilder.new(title: plain, submit: plain)
builder.add_all(homogeneous_array)
builder.add_all(mixed_tuple)
builder.add_all(Phase0CollectionPass::AllowedSections.new(section))
builder.add_all(Phase0CollectionPass::AllowedMixedBlocks.new(section))

component = Slack::UI::Checked::Proof::ReusableSummary.new("*Reusable*")
builder.add(component.render)
component.render_into(builder)
builder.build.to_json
