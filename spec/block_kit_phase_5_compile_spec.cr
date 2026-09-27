require "./spec_helper"
require "./support/compile_contracts"

describe "Phase 5 static choice compiler contracts" do
  root = File.expand_path("..", __DIR__)

  it "compiles typed choices, custom enumerables, components, and all surface builders" do
    CompileContracts.assert_pass(CompileContracts.compile(root, "spec/fixtures/compile/pass/phase_5_static_select.cr"))
  end

  {
    "phase_5_option_markdown"                     => "no overload matches",
    "phase_5_option_description_markdown"         => "no overload matches",
    "phase_5_option_url"                          => "no parameter named",
    "phase_5_option_missing_value"                => "missing argument",
    "phase_5_group_markdown"                      => "no overload matches",
    "phase_5_group_missing_options"               => "missing argument",
    "phase_5_single_missing_source"               => "no overload matches",
    "phase_5_multi_missing_source"                => "no overload matches",
    "phase_5_single_both_sources"                 => "no overload matches",
    "phase_5_multi_both_sources"                  => "no overload matches",
    "phase_5_single_nil_source"                   => "no overload matches",
    "phase_5_multi_nil_source"                    => "no overload matches",
    "phase_5_single_multi_initial"                => "no overload matches",
    "phase_5_multi_single_initial"                => "no overload matches",
    "phase_5_single_placeholder_markdown"         => "no overload matches",
    "phase_5_multi_max_type"                      => "no overload matches",
    "phase_5_single_external_field"               => "no overload matches",
    "phase_5_single_type_override"                => "no overload matches",
    "phase_5_option_setter"                       => "undefined method 'value='",
    "phase_5_group_setter"                        => "undefined method 'options='",
    "phase_5_single_setter"                       => "undefined method 'options='",
    "phase_5_multi_setter"                        => "undefined method 'initial_options='",
    "phase_5_select_deserialization"              => "wrong number of arguments",
    "phase_5_context_select"                      => "checked context rejects its declared element item type",
    "phase_5_message_element"                     => "expected argument #1",
    "phase_5_message_input"                       => "checked message rejects its declared block item type",
    "phase_5_display_input"                       => "expected argument #1",
    "phase_5_options_declared_enumerable"         => "checked options rejects its declared item type",
    "phase_5_multi_options_declared_enumerable"   => "checked options rejects its declared item type",
    "phase_5_group_options_declared_enumerable"   => "checked options rejects its declared item type",
    "phase_5_groups_declared_enumerable"          => "checked option groups rejects its declared item type",
    "phase_5_multi_groups_declared_enumerable"    => "checked option groups rejects its declared item type",
    "phase_5_initial_declared_enumerable"         => "checked options rejects its declared item type",
    "phase_5_actions_declared_enumerable"         => "checked actions rejects its declared element item type",
    "phase_5_builder_actions_declared_enumerable" => "checked actions rejects its declared element item type",
  }.each do |name, diagnostic|
    it "rejects #{name} after its positive pair compiles" do
      CompileContracts.assert_pass(CompileContracts.compile(root, "spec/fixtures/compile/pass/phase_5_static_select.cr"))
      CompileContracts.assert_fail(CompileContracts.compile(root, "spec/fixtures/compile/fail/#{name}.cr"), diagnostic)
    end
  end

  ["spec/fixtures/compile/pass/phase_5_static_select.cr", "examples/block_kit_static_select.cr"].each do |fixture|
    it "executes #{fixture} offline without Slack credentials" do
      CompileContracts.assert_pass(CompileContracts.execute(root, fixture, {
        "SLACK_CLIENT_ID" => nil, "SLACK_CLIENT_SECRET" => nil,
        "SLACK_SIGNING_SECRET" => nil, "SLACK_TEAM_AUTH_TOKEN" => nil,
      }))
    end
  end
end
