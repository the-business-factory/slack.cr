require "../../spec_helper"
require "../../support/block_kit/static_select_fixture"

alias ChoiceUI = Slack::UI::Checked

private def choice_error(&block : ->) : Array(Tuple(String, String))
  expect_raises(ChoiceUI::ValidationError) { block.call }.issues.map { |issue| {issue.code, issue.path} }
end

describe "Checked static choices" do
  it "serializes all single and multi fields against wire fixtures" do
    JSON.parse(StaticSelectFixture.single.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/phase_5_static_select.json"))
    JSON.parse(StaticSelectFixture.multi.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/phase_5_multi_static_select.json"))
  end

  it "omits optional fields and preserves empty values, false, and empty initial selections" do
    option = ChoiceUI::CompositionObjects::Option.new(text: ChoiceUI.plain("Empty"), value: "")
    single = ChoiceUI::BlockElements::StaticSelect.new(options: {option})
    JSON.parse(single.to_json).as_h.keys.sort!.should eq ["options", "type"]
    single.options.try(&.first.value).should eq ""
    group = ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("Group"), options: {option})
    grouped = ChoiceUI::BlockElements::StaticSelect.new(option_groups: {group}, initial_option: option)
    JSON.parse(grouped.to_json).as_h.has_key?("options").should be_false
    multi = ChoiceUI::BlockElements::MultiStaticSelect.new(options: {option}, initial_options: [] of ChoiceUI::CompositionObjects::Option, focus_on_load: false)
    JSON.parse(multi.to_json)["initial_options"].as_a.should be_empty
    JSON.parse(multi.to_json)["focus_on_load"].as_bool.should be_false
    JSON.parse(ChoiceUI::BlockElements::MultiStaticSelect.new(options: {option}).to_json).as_h.keys.sort!.should eq ["options", "type"]
  end

  it "counts characters at option and group boundaries" do
    option = ChoiceUI::CompositionObjects::Option.new(text: ChoiceUI.plain("界" * 75), value: "界" * 150, description: ChoiceUI.plain("界" * 75))
    ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("界" * 75), options: {option}).validate.should be_empty
    choice_error { ChoiceUI::CompositionObjects::Option.new(text: ChoiceUI.plain("界" * 76), value: "x") }.should eq [{"option.text.too_long", "text.text"}]
    choice_error { ChoiceUI::CompositionObjects::Option.new(text: ChoiceUI.plain("X"), value: "x" * 151) }.should eq [{"option.value.too_long", "value"}]
    choice_error { ChoiceUI::CompositionObjects::Option.new(text: ChoiceUI.plain("X"), value: "x", description: ChoiceUI.plain("x" * 76)) }.should eq [{"option.description.too_long", "description.text"}]
    choice_error { ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("x" * 76), options: {option}) }.should eq [{"option_group.label.too_long", "label.text"}]
  end

  it "validates one to 100 choices or groups and 100 choices per group" do
    options = (1..100).map { |index| StaticSelectFixture.option(index.to_s) }
    ChoiceUI::BlockElements::StaticSelect.new(options: options, action_id: "界" * 255, placeholder: ChoiceUI.plain("界" * 150)).validate.should be_empty
    groups = (1..100).map do |index|
      ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain(index.to_s), options: {StaticSelectFixture.option(index.to_s)})
    end
    ChoiceUI::BlockElements::MultiStaticSelect.new(option_groups: groups).validate.should be_empty
    group = ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("First"), options: options)
    second = ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("Second"), options: options.map { |option| StaticSelectFixture.option("second-#{option.value}") })
    ChoiceUI::BlockElements::MultiStaticSelect.new(option_groups: {group, second}).validate.should be_empty
    choice_error { ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("Empty"), options: [] of ChoiceUI::CompositionObjects::Option) }.first.should eq({"option_group.options.size", "options"})
    choice_error { ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("Large"), options: options + [StaticSelectFixture.option("101")]) }.first.should eq({"option_group.options.size", "options"})
    choice_error { ChoiceUI::BlockElements::StaticSelect.new(options: [] of ChoiceUI::CompositionObjects::Option) }.first.should eq({"static_select.options.size", "options"})
    choice_error { ChoiceUI::BlockElements::MultiStaticSelect.new(options: options + [StaticSelectFixture.option("101")]) }.first.should eq({"multi_static_select.options.size", "options"})
    choice_error { ChoiceUI::BlockElements::StaticSelect.new(option_groups: [] of ChoiceUI::CompositionObjects::OptionGroup) }.first.should eq({"static_select.option_groups.size", "option_groups"})
    choice_error { ChoiceUI::BlockElements::MultiStaticSelect.new(option_groups: groups + [group]) }.first.should eq({"multi_static_select.option_groups.size", "option_groups"})
    choice_error { ChoiceUI::BlockElements::StaticSelect.new(options: options, action_id: "x" * 256, placeholder: ChoiceUI.plain("x" * 151)) }.should eq [
      {"static_select.action_id.too_long", "action_id"}, {"static_select.placeholder.too_long", "placeholder.text"},
    ]
  end

  it "rejects repeated values across groups and across element types in Actions" do
    option = StaticSelectFixture.option
    choice_error { ChoiceUI::BlockElements::StaticSelect.new(options: {option, option}) }.should eq [{"static_select.options.value.duplicate", "options[1].value"}]
    choice_error { ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("Group"), options: {option, option}) }.should eq [{"option_group.options.value.duplicate", "options[1].value"}]
    group = ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("Group"), options: {option})
    choice_error { ChoiceUI::BlockElements::MultiStaticSelect.new(option_groups: {group, group}) }.should eq [{"multi_static_select.options.value.duplicate", "option_groups[1].options[0].value"}]
    choice_error do
      ChoiceUI::Blocks::Actions.new(elements: {StaticSelectFixture.single, ChoiceUI::BlockElements::Button.new(text: ChoiceUI.plain("Go"), action_id: "color")})
    end.should eq [{"actions.action_id.duplicate", "elements[1].action_id"}]
  end

  it "requires exact initial matches including descriptions and emoji" do
    option = StaticSelectFixture.option
    variants = [
      StaticSelectFixture.option("missing"), StaticSelectFixture.option("red", "Different"),
      ChoiceUI::CompositionObjects::Option.new(text: ChoiceUI.plain("Red", emoji: false), value: "red"),
      ChoiceUI::CompositionObjects::Option.new(text: ChoiceUI.plain("Red"), value: "red", description: ChoiceUI.plain("Team color")),
    ]
    group = ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("Group"), options: {option})
    variants.each do |initial|
      choice_error { ChoiceUI::BlockElements::StaticSelect.new(option_groups: {group}, initial_option: initial) }.should eq [{"static_select.initial_option.not_found", "initial_option"}]
      choice_error { ChoiceUI::BlockElements::MultiStaticSelect.new(options: {option}, initial_options: {initial}) }.should eq [{"multi_static_select.initial_option.not_found", "initial_options[0]"}]
    end
    ChoiceUI::BlockElements::StaticSelect.new(options: {option}, initial_option: StaticSelectFixture.option).validate.should be_empty
  end

  it "checks multi selection limits and duplicate initial selections" do
    option = StaticSelectFixture.option
    other = StaticSelectFixture.option("blue", "Blue")
    ChoiceUI::BlockElements::MultiStaticSelect.new(options: {option}, initial_options: {option}, max_selected_items: 1).validate.should be_empty
    ChoiceUI::BlockElements::MultiStaticSelect.new(options: {option}, max_selected_items: Int32::MAX).validate.should be_empty
    choice_error { ChoiceUI::BlockElements::MultiStaticSelect.new(options: {option}, max_selected_items: 0) }.should eq [{"multi_static_select.max_selected_items.too_small", "max_selected_items"}]
    choice_error { ChoiceUI::BlockElements::MultiStaticSelect.new(options: {option, other}, initial_options: {option, other}, max_selected_items: 1) }.should eq [{"multi_static_select.initial_options.too_many", "initial_options"}]
    choice_error { ChoiceUI::BlockElements::MultiStaticSelect.new(options: {option}, initial_options: {option, option}) }.should eq [{"multi_static_select.initial_options.duplicate", "initial_options[1]"}]
  end

  it "copies nested choice collections and retained builders" do
    options = [StaticSelectFixture.option]
    initial = options.dup
    group = ChoiceUI::CompositionObjects::OptionGroup.new(label: ChoiceUI.plain("Group"), options: options)
    groups = [group]
    single = ChoiceUI::BlockElements::StaticSelect.new(options: options)
    multi = ChoiceUI::BlockElements::MultiStaticSelect.new(option_groups: groups, initial_options: initial)
    builder = ChoiceUI::HomeBuilder.new
    builder.actions({single, multi})
    snapshot = builder.build
    before = snapshot.to_json
    options.clear
    initial.clear
    groups.clear
    group.options.clear
    single.options.try(&.clear)
    multi.option_groups.try(&.each(&.options.clear))
    multi.option_groups.try(&.clear)
    multi.initial_options.try(&.clear)
    builder.divider
    snapshot.blocks.clear
    snapshot.to_json.should eq before
    builder.build.blocks.size.should eq 2
  end

  it "supports both variants in every declared parent and surface" do
    {StaticSelectFixture.single, StaticSelectFixture.multi}.each do |element|
      section = ChoiceUI::Blocks::Section.new(text: ChoiceUI.plain("Color"), accessory: element)
      actions = ChoiceUI::Blocks::Actions.new(elements: {element})
      input = ChoiceUI::Blocks::Input.new(label: ChoiceUI.plain("Color"), element: element)
      {section, actions}.each do |block|
        ChoiceUI::Message.new(fallback_text: "Color", blocks: {block}).validate.should be_empty
        ChoiceUI::DisplayModal.new(title: ChoiceUI.plain("Color"), blocks: {block}).validate.should be_empty
      end
      {section, actions, input}.each do |block|
        ChoiceUI::Home.new(blocks: {block}).validate.should be_empty
        ChoiceUI::FormModal.new(title: ChoiceUI.plain("Color"), submit: ChoiceUI.plain("Save"), blocks: {block}).validate.should be_empty
      end
    end
  end

  it "checks focus across Section, Actions, and Input in all view builders" do
    option = StaticSelectFixture.option
    single = ChoiceUI::BlockElements::StaticSelect.new(options: {option}, focus_on_load: true)
    multi = ChoiceUI::BlockElements::MultiStaticSelect.new(options: {option}, focus_on_load: true)
    builders = {ChoiceUI::HomeBuilder.new, ChoiceUI::FormModalBuilder.new(title: ChoiceUI.plain("Color"), submit: ChoiceUI.plain("Save")), ChoiceUI::DisplayModalBuilder.new(title: ChoiceUI.plain("Color"))}
    builders.each do |builder|
      builder.section(ChoiceUI.plain("Color"), accessory: single)
      builder.actions({single, multi})
      surface = builder.is_a?(ChoiceUI::HomeBuilder) ? "home" : "modal"
      choice_error { builder.build }.should eq [
        {"#{surface}.focus_on_load.duplicate", "blocks[1].elements[0].focus_on_load"},
        {"#{surface}.focus_on_load.duplicate", "blocks[1].elements[1].focus_on_load"},
      ]
    end
    {ChoiceUI::HomeBuilder.new, ChoiceUI::FormModalBuilder.new(title: ChoiceUI.plain("Color"), submit: ChoiceUI.plain("Save"))}.each do |builder|
      builder.section(ChoiceUI.plain("Color"), accessory: single)
      builder.input(label: ChoiceUI.plain("Note"), element: ChoiceUI::BlockElements::PlainTextInput.new(focus_on_load: true))
      error = expect_raises(ChoiceUI::ValidationError) { builder.build }
      error.issues.map(&.path).should eq ["blocks[1].element.focus_on_load"]
    end
  end
end
