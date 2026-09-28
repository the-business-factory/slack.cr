require "../../src/slack"

# Builds a remote file block for an application's own `chat.unfurl` request.
# Slack does not let apps add file blocks to messages directly; share a remote
# file with `files.remote.share`. This library wraps neither method.
module OfflineRemoteFileExample
  alias UI = Slack::UI

  def self.run(output : IO = STDOUT) : Nil
    link = "https://docs.example.test/plans/2026-q4"
    file = UI::Blocks::File.new(external_id: "plan-2026-q4", block_id: "plan.file")
    unfurls = JSON.build do |json|
      json.object do
        json.field link do
          json.object do
            json.field "blocks", {file}
          end
        end
      end
    end
    output.puts unfurls
  end
end
