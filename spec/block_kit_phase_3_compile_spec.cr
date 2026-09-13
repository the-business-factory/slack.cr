require "./spec_helper"
require "./support/compile_contracts"

describe "Block Kit Phase 3 public compile contracts" do
  root = File.expand_path("..", __DIR__)

  %w[phase_3_modal phase_3_endpoint].each do |name|
    it "compiles #{name}" do
      CompileContracts.assert_pass(CompileContracts.compile(root, "spec/fixtures/compile/pass/#{name}.cr"))
    end
  end

  {
    "phase_3_display_input"                       => {"phase_3_modal", "checked display_modal rejects its declared block item type"},
    "phase_3_display_builder_input"               => {"phase_3_modal", "expected argument #1 to 'Slack::UI::Checked::DisplayModalBuilder#add'"},
    "phase_3_display_builder_input_helper"        => {"phase_3_modal", "undefined method 'input' for Slack::UI::Checked::DisplayModalBuilder"},
    "phase_3_message_builder_input_helper"        => {"phase_3_modal", "undefined method 'input' for Slack::UI::Checked::MessageBuilder"},
    "phase_3_form_missing_submit"                 => {"phase_3_modal", "missing argument: submit"},
    "phase_3_form_builder_missing_submit"         => {"phase_3_modal", "missing argument: submit"},
    "phase_3_form_helper_missing_submit"          => {"phase_3_modal", "missing argument: submit"},
    "phase_3_form_nil_submit"                     => {"phase_3_modal", "expected argument 'submit'"},
    "phase_3_input_mrkdwn_label"                  => {"phase_3_modal", "expected argument 'label'"},
    "phase_3_input_button"                        => {"phase_3_modal", "expected argument 'element'"},
    "phase_3_input_mrkdwn_placeholder"            => {"phase_3_modal", "expected argument 'placeholder'"},
    "phase_3_modal_mrkdwn_title"                  => {"phase_3_modal", "expected argument 'title'"},
    "phase_3_message_input"                       => {"phase_3_modal", "checked message rejects its declared block item type"},
    "phase_3_input_accessory"                     => {"phase_3_modal", "expected argument 'accessory'"},
    "phase_3_input_setter"                        => {"phase_3_modal", "undefined method 'min_length='"},
    "phase_3_modal_setter"                        => {"phase_3_modal", "undefined method 'submit='"},
    "phase_3_dispatch_string"                     => {"phase_3_modal", "checked dispatch config rejects its declared trigger item type"},
    "phase_3_display_declared_enumerable"         => {"phase_3_modal", "checked display_modal rejects its declared block item type"},
    "phase_3_display_builder_declared_enumerable" => {"phase_3_modal", "checked display_modal rejects its declared block item type"},
    "phase_3_form_declared_enumerable"            => {"phase_3_modal", "checked form_modal rejects its declared block item type"},
    "phase_3_form_builder_declared_enumerable"    => {"phase_3_modal", "checked form_modal rejects its declared block item type"},
    "phase_3_request_deserialization"             => {"phase_3_endpoint", "checked request deserialization is unsupported"},
    "phase_3_legacy_view"                         => {"phase_3_endpoint", "no overload matches 'Slack::Api::CheckedViewsOpen.new'"},
  }.each do |name, pair|
    it "rejects #{name} after its positive pair compiles" do
      CompileContracts.assert_pass(CompileContracts.compile(root, "spec/fixtures/compile/pass/#{pair[0]}.cr"))
      CompileContracts.assert_fail(CompileContracts.compile(root, "spec/fixtures/compile/fail/#{name}.cr"), pair[1])
    end
  end

  ["spec/fixtures/compile/pass/phase_3_modal.cr", "examples/block_kit_modal.cr"].each do |fixture|
    it "executes #{fixture} offline without Slack credentials" do
      result = CompileContracts.execute(root, fixture, {
        "SLACK_CLIENT_ID"       => nil,
        "SLACK_CLIENT_SECRET"   => nil,
        "SLACK_SIGNING_SECRET"  => nil,
        "SLACK_TEAM_AUTH_TOKEN" => nil,
      })
      CompileContracts.assert_pass(result)
    end
  end
end
