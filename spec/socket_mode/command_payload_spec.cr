require "../spec_helper"

private def command_payload(**overrides) : String
  fields = {
    "api_app_id"   => "A-SYNTHETIC",
    "team_id"      => "T-SYNTHETIC",
    "channel_id"   => "C-SYNTHETIC",
    "channel_name" => "general",
    "user_id"      => "U-SYNTHETIC",
    "user_name"    => "synthetic.user",
    "command"      => "/deploy",
    "text"         => "release-42",
    "response_url" => "https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic",
    "trigger_id"   => "1710000000.synthetic.trigger",
  } of String => String | Bool
  overrides.each { |key, value| fields[key.to_s] = value }
  fields.to_json
end

private def parse_failure(reason : Symbol, &)
  error = expect_raises(Slack::Auth::RequestAuthorizationError) { yield }
  error.reason.should eq(reason)
end

describe "Slack::Commands::Parser.from_json_object" do
  it "accepts the install kind as a string or a JSON boolean" do
    Slack::Commands::Parser.from_json_object(command_payload(is_enterprise_install: "true")).is_enterprise_install.should be_true
    Slack::Commands::Parser.from_json_object(command_payload(is_enterprise_install: false)).is_enterprise_install.should be_false
    Slack::Commands::Parser.from_json_object(command_payload).is_enterprise_install.should be_nil
  end

  it "rejects a malformed install kind like the form parser" do
    parse_failure(:invalid_install_kind) { Slack::Commands::Parser.from_json_object(command_payload(is_enterprise_install: "yes")) }
  end

  it "rejects a duplicate routing field and keeps the last duplicate of other fields" do
    parse_failure(:duplicate_routing_field) do
      Slack::Commands::Parser.from_json_object(command_payload.sub(%("user_id":), %("user_id":"U-OTHER","user_id":)))
    end

    command = Slack::Commands::Parser.from_json_object(command_payload.sub(%("text":), %("text":"first","text":)))
    command.text.should eq("release-42")
  end
end
