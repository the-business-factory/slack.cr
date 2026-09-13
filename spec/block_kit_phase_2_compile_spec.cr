require "./spec_helper"
require "./support/compile_contracts"

describe "Block Kit Phase 2 public compile contracts" do
  root = File.expand_path("..", __DIR__)

  %w[phase_2_message phase_2_endpoint].each do |name|
    it "compiles the #{name} positive contract" do
      fixture = "spec/fixtures/compile/pass/#{name}.cr"
      result = CompileContracts.compile(root, fixture)
      CompileContracts.assert_pass(result)
      puts "#{fixture}: #{result.elapsed.total_milliseconds.round(1)} ms"
    end
  end

  {
    "phase_2_forbidden_declared_enumerable" => {"phase_2_message", "checked message rejects its declared block item type"},
    "phase_2_invalid_actions_element"       => {"phase_2_message", "checked actions rejects its declared element item type"},
    "phase_2_invalid_builder_block"         => {"phase_2_message", "expected argument #1 to 'Slack::UI::Checked::MessageBuilder#add'"},
    "phase_2_invalid_message_block"         => {"phase_2_message", "checked message rejects its declared block item type"},
    "phase_2_confirmation_title_mrkdwn"     => {"phase_2_message", "expected argument 'title'"},
    "phase_2_section_missing_content"       => {"phase_2_message", "wrong number of arguments"},
    "phase_2_message_setter"                => {"phase_2_message", "undefined method 'fallback_text='"},
    "phase_2_request_deserialization"       => {"phase_2_endpoint", "checked request deserialization is unsupported"},
  }.each do |name, pair|
    it "rejects the #{name} negative contract after its positive pair compiles" do
      positive = CompileContracts.compile(root, "spec/fixtures/compile/pass/#{pair[0]}.cr")
      CompileContracts.assert_pass(positive)

      fixture = "spec/fixtures/compile/fail/#{name}.cr"
      result = CompileContracts.compile(root, fixture)
      CompileContracts.assert_fail(result, pair[1])
      puts "#{fixture}: #{result.elapsed.total_milliseconds.round(1)} ms"
    end
  end

  it "executes the UI-only message example with Slack credentials removed" do
    result = CompileContracts.execute(root, "spec/fixtures/compile/pass/phase_2_message.cr", {
      "SLACK_CLIENT_ID"       => nil,
      "SLACK_CLIENT_SECRET"   => nil,
      "SLACK_SIGNING_SECRET"  => nil,
      "SLACK_TEAM_AUTH_TOKEN" => nil,
    })
    CompileContracts.assert_pass(result)
  end

  it "executes the documented custom component example without credentials" do
    result = CompileContracts.execute(root, "examples/block_kit_message.cr", {
      "SLACK_CLIENT_ID"       => nil,
      "SLACK_CLIENT_SECRET"   => nil,
      "SLACK_SIGNING_SECRET"  => nil,
      "SLACK_TEAM_AUTH_TOKEN" => nil,
    })
    CompileContracts.assert_pass(result)
  end
end
