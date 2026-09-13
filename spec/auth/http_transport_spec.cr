require "../spec_helper"
require "file_utils"

describe Slack::Auth::HTTPTransport do
  it "passes the independent native wire suite without loading WebMock" do
    cache_directory = File.tempname("slack-native-http-transport-cache")
    Dir.mkdir(cache_directory)
    output = IO::Memory.new
    status = Process.run(
      "crystal",
      ["spec", "spec/support/processes/http_transport_native.cr"],
      chdir: File.expand_path("../..", __DIR__),
      env: {"CRYSTAL_CACHE_DIR" => cache_directory},
      output: output,
      error: output
    )

    status.success?.should be_true, output.to_s
  ensure
    FileUtils.rm_rf(cache_directory) if cache_directory
  end
end
