require "../spec_helper"
require "../support/compile_contracts"

describe "Socket Mode transport" do
  it "parses frames and acknowledges envelopes without the event, interaction, and command implementations" do
    root = File.expand_path("../..", __DIR__)
    CompileContracts.assert_pass(CompileContracts.compile(root, "spec/fixtures/compile/pass/socket_mode_transport.cr"))
  end
end
