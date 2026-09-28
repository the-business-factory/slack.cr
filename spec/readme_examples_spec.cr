require "./spec_helper"

describe "README examples list" do
  it "names each runnable example exactly once" do
    root = File.expand_path("..", __DIR__)
    listed = File.read(File.join(root, "README.md")).scan(/^crystal run (examples\/\w+\.cr)$/m).map(&.[1])
    present = Dir.children(File.join(root, "examples")).select(&.ends_with?(".cr")).map { |name| "examples/#{name}" }

    listed.size.should eq(listed.uniq.size), "README lists an example more than once"
    listed.sort.should eq(present.sort)
  end
end
