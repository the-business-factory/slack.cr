require "./spec_helper"
require "./support/compile_contracts"
require "file/tempfile"

# Startup environment defaults cannot be reset by an ordinary in-process spec.
describe "full-library startup" do
  it "loads slack and constructs UI without credentials or redirect settings" do
    root = File.expand_path("..", __DIR__)
    crystal_path = IO::Memory.new
    Process.run("crystal", ["env", "CRYSTAL_PATH"], output: crystal_path).success?.should be_true
    library_dir = File.tempname("slack-startup")
    Dir.mkdir(library_dir)
    begin
      File.symlink(root, File.join(library_dir, "slack"))
      result = CompileContracts.execute(root, "spec/support/entrypoints/startup.cr", {
        "CRYSTAL_PATH" => "#{library_dir}:#{crystal_path.to_s.strip}",
        "SLACK_CLIENT_ID" => nil, "SLACK_CLIENT_SECRET" => nil,
        "SLACK_SIGNING_SECRET" => nil, "SLACK_TEAM_AUTH_TOKEN" => nil,
        "OAUTH_REDIRECT_URL" => nil, "SIGN_IN_REDIRECT_URL" => nil,
      })
      CompileContracts.assert_pass(result)
    ensure
      File.delete?(File.join(library_dir, "slack"))
      Dir.delete(library_dir)
    end
  end
end
