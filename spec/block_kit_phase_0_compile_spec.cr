require "./spec_helper"
require "./support/compile_contracts"

describe "Block Kit Phase 0 compile contracts" do
  root = File.expand_path("..", __DIR__)
  pass_fixtures = %w[
    collections_and_surfaces
    legacy_endpoint
    nested_surfaces
    text_types
    ui_only
  ]

  pass_fixtures.each do |name|
    it "compiles the #{name} positive contract" do
      fixture = "spec/fixtures/compile/pass/#{name}.cr"
      result = CompileContracts.compile(root, fixture)
      CompileContracts.assert_pass(result)
      puts "#{fixture}: #{result.elapsed.total_milliseconds.round(1)} ms"
    end
  end

  {
    "checked_setter"                  => {"text_types", "undefined method 'text='"},
    "checked_button_setter"           => {"text_types", "undefined method 'style='"},
    "checked_section_setter"          => {"text_types", "undefined method 'fields='"},
    "current_request_deserialization" => {"legacy_endpoint", "can't instantiate abstract struct Slack::UI::Block"},
    "display_modal_input"             => {"nested_surfaces", "display modal rejects its declared block item type"},
    "forbidden_declared_enumerable"   => {"collections_and_surfaces", "form modal rejects its declared block item type"},
    "forbidden_nested_surface"        => {"nested_surfaces", "form modal rejects its declared block item type"},
    "form_modal_missing_submit"       => {"nested_surfaces", "missing argument: submit"},
    "invalid_accessory"               => {"text_types", "accessory"},
    "mrkdwn_button_label"             => {"text_types", "PlainText, not Slack::UI::Checked::CompositionObjects::Mrkdwn"},
    "request_deserialization"         => {"legacy_endpoint", "checked request deserialization is unsupported"},
  }.each do |name, pair|
    it "rejects the #{name} negative contract after its #{pair[0]} pair compiles" do
      positive = CompileContracts.compile(root, "spec/fixtures/compile/pass/#{pair[0]}.cr")
      CompileContracts.assert_pass(positive)

      fixture = "spec/fixtures/compile/fail/#{name}.cr"
      result = CompileContracts.compile(root, fixture)
      CompileContracts.assert_fail(result, pair[1])
      puts "#{fixture}: #{result.elapsed.total_milliseconds.round(1)} ms"
    end
  end

  it "executes the UI-only entrypoint with Slack credentials removed" do
    fixture = "spec/fixtures/compile/pass/ui_only.cr"
    result = CompileContracts.execute(root, fixture, {
      "SLACK_CLIENT_ID"       => nil,
      "SLACK_CLIENT_SECRET"   => nil,
      "SLACK_SIGNING_SECRET"  => nil,
      "SLACK_TEAM_AUTH_TOKEN" => nil,
    })
    CompileContracts.assert_pass(result)
  end
end
