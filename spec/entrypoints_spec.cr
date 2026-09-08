require "spec"
require "file/tempfile"

# Separate compilers prevent the suite's requires from hiding missing dependencies.
describe "public entrypoints" do
  root = File.expand_path("..", __DIR__)
  crystal_path = IO::Memory.new
  Process.run("crystal", ["env", "CRYSTAL_PATH"], output: crystal_path).success?.should be_true

  %w[core oauth core_then_oauth oauth_then_core].each do |consumer|
    it "supports #{consumer} with optional redirects" do
      # Model a consumer's lib/slack checkout for the actual public require paths.
      library_dir = File.tempname("slack-entrypoints")
      Dir.mkdir(library_dir)
      begin
        File.symlink(root, File.join(library_dir, "slack"))
        output = IO::Memory.new
        status = Process.run("crystal", ["run", "spec/support/entrypoints/#{consumer}.cr"],
          chdir: root,
          env: {
            "CRYSTAL_PATH"         => "#{library_dir}:#{crystal_path.to_s.strip}",
            "OAUTH_REDIRECT_URL"   => nil,
            "SIGN_IN_REDIRECT_URL" => nil,
          }, output: output, error: output)
        status.success?.should be_true, output.to_s
      ensure
        File.delete?(File.join(library_dir, "slack"))
        Dir.delete(library_dir)
      end
    end
  end
end
