require "./spec_helper"
require "./support/compile_contracts"

# A consumer's `require "slack"` cannot be reproduced inside this executable,
# which already loads the spec helper and `slack/testing`.
describe "full-library startup" do
  it "builds a consumer that only requires slack from CRYSTAL_PATH" do
    root = File.expand_path("..", __DIR__)
    crystal_path = IO::Memory.new
    Process.run("crystal", ["env", "CRYSTAL_PATH"], output: crystal_path).success?.should be_true
    library_dir = File.tempname("slack-startup")
    Dir.mkdir(library_dir)
    begin
      File.symlink(root, File.join(library_dir, "slack"))
      env = Hash(String, String?){"CRYSTAL_PATH" => "#{library_dir}:#{crystal_path.to_s.strip}"}
      CompileContracts.assert_pass(CompileContracts.compile(root, "spec/support/entrypoints/startup.cr", env, codegen: true))
    ensure
      File.delete?(File.join(library_dir, "slack"))
      Dir.delete(library_dir)
    end
  end
end
