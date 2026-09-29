require "../spec_helper"
require "../support/one_pass"

module YieldedCollectionsSpec
  alias UI = Slack::UI

  describe "yielded collection composition" do
    it "copies Message, Home and modal blocks once despite a broad declaration" do
      divider = UI::Blocks::Divider.new
      section = UI::Blocks::Section.new(text: UI.plain("Kept"))
      source = [divider, section]
      collections = Array.new(5) { SpecSupport::OnePass.new(source) }
      surfaces = {
        UI::Message.new(fallback_text: "Kept", blocks: collections[0]),
        UI::Message.with_slack_generated_fallback(blocks: collections[1]),
        UI::Home.new(blocks: collections[2]),
        UI::DisplayModal.new(title: UI.plain("Kept"), blocks: collections[3]),
        UI::FormModal.new(title: UI.plain("Kept"), submit: UI.plain("Save"), blocks: collections[4]),
      }
      source.clear
      surfaces.each do |surface|
        surface.blocks.clear
        payload = JSON.parse(surface.to_json)
        payload["blocks"].as_a.map(&.["type"].as_s).should eq %w[divider section]
        payload["blocks"][1]["text"]["text"].should eq "Kept"
      end
      collections.map(&.passes).should eq [1, 1, 1, 1, 1]
    end

    it "preserves empty collection behavior without a second enumeration" do
      empty = SpecSupport::OnePass.new([] of UI::Blocks::Divider)
      UI::Home.new(blocks: empty).blocks.empty?.should be_true
      empty.passes.should eq 1
      expect_raises(UI::ValidationError) do
        UI::Message.new(fallback_text: "Empty", blocks: SpecSupport::OnePass.new([] of UI::Blocks::Divider))
      end
    end

    it "adds broad component collections through each surface builder once" do
      {UI::MessageBuilder.new(fallback_text: "Kept"), UI::HomeBuilder.new,
       UI::DisplayModalBuilder.new(title: UI.plain("Kept")),
       UI::FormModalBuilder.new(title: UI.plain("Kept"), submit: UI.plain("Save"))}.each do |builder|
        values = SpecSupport::OnePass.new([UI::Blocks::Divider.new, UI::Blocks::Section.new(text: UI.plain("Kept"))])
        builder.add_all(values)
        first = builder.build
        builder.divider
        first.blocks.map(&.type).should eq %w[divider section]
        values.passes.should eq 1
      end
    end

    it "copies yielded text, actions and context values into typed snapshots" do
      plain = UI.plain("Kept")
      field_source = [plain]
      fields = SpecSupport::OnePass.new(field_source)
      section = UI::Blocks::Section.new(fields: fields)
      field_source.clear
      section.fields.should_not(be_nil).map(&.text).should eq ["Kept"]
      fields.passes.should eq 1
      with_text = UI::Blocks::Section.new(text: plain, fields: SpecSupport::OnePass.new([plain]))
      with_text.fields.should_not(be_nil).size.should eq 1

      button = UI::BlockElements::Button.new(text: plain, action_id: "kept")
      actions = UI::Blocks::Actions.new(elements: SpecSupport::OnePass.new([button]))
      JSON.parse(actions.to_json)["elements"].as_a.map(&.["action_id"].as_s).should eq ["kept"]
      context = UI::Blocks::Context.new(elements: SpecSupport::OnePass.new([plain]))
      JSON.parse(context.to_json)["elements"].as_a.map(&.["text"].as_s).should eq ["Kept"]
      builder = UI::MessageBuilder.new(fallback_text: "Kept")
      builder.actions(SpecSupport::OnePass.new([button]))
      builder.context(SpecSupport::OnePass.new([plain]))
      builder.build.blocks.map(&.type).should eq %w[actions context]
    end

    it "copies option, group, initial selection and dispatch inputs once" do
      option = UI::CompositionObjects::Option.new(text: UI.plain("Kept"), value: "kept")
      group = UI::CompositionObjects::OptionGroup.new(label: UI.plain("Group"), options: SpecSupport::OnePass.new([option]))
      single = UI::BlockElements::StaticSelect.new(options: SpecSupport::OnePass.new([option]), initial_option: option)
      grouped = UI::BlockElements::StaticSelect.new(option_groups: SpecSupport::OnePass.new([group]), initial_option: option)
      multi = UI::BlockElements::MultiStaticSelect.new(options: SpecSupport::OnePass.new([option]), initial_options: SpecSupport::OnePass.new([option]))
      multi_grouped = UI::BlockElements::MultiStaticSelect.new(option_groups: SpecSupport::OnePass.new([group]), initial_options: SpecSupport::OnePass.new([option]))
      {single, multi}.each do |menu|
        menu.options.should_not(be_nil).clear
        JSON.parse(menu.to_json)["options"].as_a.map(&.["value"].as_s).should eq ["kept"]
      end
      {grouped, multi_grouped}.each do |menu|
        menu.option_groups.should_not(be_nil).clear
        JSON.parse(menu.to_json)["option_groups"][0]["options"].as_a.map(&.["value"].as_s).should eq ["kept"]
      end
      JSON.parse(multi.to_json)["initial_options"].as_a.map(&.["value"].as_s).should eq ["kept"]
      JSON.parse(multi_grouped.to_json)["initial_options"].as_a.map(&.["value"].as_s).should eq ["kept"]
      triggers = SpecSupport::OnePass.new([UI::CompositionObjects::DispatchTrigger::OnEnterPressed])
      config = UI::CompositionObjects::DispatchActionConfig.new(triggers)
      config.trigger_actions_on.should_not(be_nil).clear
      JSON.parse(config.to_json).should eq JSON.parse(%({"trigger_actions_on":["on_enter_pressed"]}))
      triggers.passes.should eq 1
    end
  end
end
