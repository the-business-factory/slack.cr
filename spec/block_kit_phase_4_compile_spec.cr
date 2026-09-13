require "./spec_helper"
require "./support/compile_contracts"

describe "Block Kit Phase 4 public compile contracts" do
  root = File.expand_path("..", __DIR__)

  %w[phase_4_display_home phase_4_endpoint].each do |name|
    it "compiles #{name}" do
      CompileContracts.assert_pass(CompileContracts.compile(root, "spec/fixtures/compile/pass/#{name}.cr"))
    end
  end

  {
    "phase_4_header_mrkdwn"                       => {"phase_4_display_home", "expected argument 'text'"},
    "phase_4_header_builder_mrkdwn"               => {"phase_4_display_home", "expected argument 'text'"},
    "phase_4_image_title_mrkdwn"                  => {"phase_4_display_home", "no overload matches"},
    "phase_4_image_builder_title_mrkdwn"          => {"phase_4_display_home", "no overload matches"},
    "phase_4_image_missing_source"                => {"phase_4_display_home", "no overload matches"},
    "phase_4_image_both_sources"                  => {"phase_4_display_home", "no overload matches"},
    "phase_4_image_missing_alt"                   => {"phase_4_display_home", "missing argument: alt_text"},
    "phase_4_image_nil_source"                    => {"phase_4_display_home", "no overload matches"},
    "phase_4_image_element_missing_source"        => {"phase_4_display_home", "no overload matches"},
    "phase_4_image_element_both_sources"          => {"phase_4_display_home", "no overload matches"},
    "phase_4_image_element_missing_alt"           => {"phase_4_display_home", "missing argument: alt_text"},
    "phase_4_image_element_nil_source"            => {"phase_4_display_home", "no overload matches"},
    "phase_4_image_builder_both_sources"          => {"phase_4_display_home", "no overload matches"},
    "phase_4_image_builder_missing_alt"           => {"phase_4_display_home", "missing argument: alt_text"},
    "phase_4_slack_file_missing"                  => {"phase_4_display_home", "no overload matches"},
    "phase_4_slack_file_both"                     => {"phase_4_display_home", "no overload matches"},
    "phase_4_slack_file_nil"                      => {"phase_4_display_home", "no overload matches"},
    "phase_4_context_button"                      => {"phase_4_display_home", "checked context rejects its declared element item type"},
    "phase_4_image_in_actions"                    => {"phase_4_display_home", "checked actions rejects its declared element item type"},
    "phase_4_image_in_input"                      => {"phase_4_display_home", "expected argument 'element'"},
    "phase_4_image_element_home"                  => {"phase_4_display_home", "checked home rejects its declared block item type"},
    "phase_4_image_block_context"                 => {"phase_4_display_home", "checked context rejects its declared element item type"},
    "phase_4_image_block_accessory"               => {"phase_4_display_home", "expected argument 'accessory'"},
    "phase_4_home_builder_element"                => {"phase_4_display_home", "expected argument #1"},
    "phase_4_home_legacy"                         => {"phase_4_endpoint", "checked home rejects its declared block item type"},
    "phase_4_home_declared_enumerable"            => {"phase_4_display_home", "checked home rejects its declared block item type"},
    "phase_4_home_builder_declared_enumerable"    => {"phase_4_display_home", "checked home rejects its declared block item type"},
    "phase_4_context_declared_enumerable"         => {"phase_4_display_home", "checked context rejects its declared element item type"},
    "phase_4_context_builder_declared_enumerable" => {"phase_4_display_home", "checked context rejects its declared element item type"},
    "phase_4_header_setter"                       => {"phase_4_display_home", "undefined method 'level='"},
    "phase_4_context_setter"                      => {"phase_4_display_home", "undefined method 'elements='"},
    "phase_4_image_setter"                        => {"phase_4_display_home", "undefined method 'alt_text='"},
    "phase_4_image_element_setter"                => {"phase_4_display_home", "undefined method 'image_url='"},
    "phase_4_slack_file_setter"                   => {"phase_4_display_home", "undefined method 'id='"},
    "phase_4_home_setter"                         => {"phase_4_display_home", "undefined method 'blocks='"},
    "phase_4_request_deserialization"             => {"phase_4_endpoint", "checked request deserialization is unsupported"},
    "phase_4_request_modal"                       => {"phase_4_endpoint", "no overload matches"},
    "phase_4_request_setter"                      => {"phase_4_endpoint", "undefined method 'user_id='"},
  }.each do |name, pair|
    it "rejects #{name} after its positive pair compiles" do
      CompileContracts.assert_pass(CompileContracts.compile(root, "spec/fixtures/compile/pass/#{pair[0]}.cr"))
      CompileContracts.assert_fail(CompileContracts.compile(root, "spec/fixtures/compile/fail/#{name}.cr"), pair[1])
    end
  end

  ["spec/fixtures/compile/pass/phase_4_display_home.cr", "examples/block_kit_home.cr"].each do |fixture|
    it "executes #{fixture} offline without Slack credentials" do
      CompileContracts.assert_pass(CompileContracts.execute(root, fixture, {
        "SLACK_CLIENT_ID" => nil, "SLACK_CLIENT_SECRET" => nil,
        "SLACK_SIGNING_SECRET" => nil, "SLACK_TEAM_AUTH_TOKEN" => nil,
      }))
    end
  end
end
