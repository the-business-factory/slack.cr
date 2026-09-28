require "../../src/slack"

# Reads the blocks of the message where a signed button click happened.
module OfflineReceivedBlocksExample
  alias Blocks = Slack::Interactions::ReceivedBlocks

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  # Independently authored Slack payload, not derived from outbound values.
  CLICK = <<-JSON
    {"type":"block_actions","team":{"id":"T-SYNTHETIC"},"user":{"id":"U-REVIEWER"},"api_app_id":"A-SYNTHETIC",
    "container":{"type":"message","message_ts":"1710000000.000100","channel_id":"C-RELEASES","is_ephemeral":false},
    "message":{"type":"message","ts":"1710000000.000100","text":"Release 2.0 needs approval.","blocks":[
      {"type":"header","block_id":"title","text":{"type":"plain_text","text":"Release 2.0","emoji":true}},
      {"type":"section","block_id":"summary","text":{"type":"mrkdwn","text":"*3* services change","verbatim":false},
       "accessory":{"type":"overflow","action_id":"release.more","options":[{"text":{"type":"plain_text","text":"Snooze"},"value":"snooze"}]}},
      {"type":"container","block_id":"changes","title":{"type":"plain_text","text":"Changes"},"child_blocks":[
        {"type":"rich_text","block_id":"notes","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"Faster deploys"}]}]}]},
      {"type":"actions","block_id":"decision","elements":[
        {"type":"button","action_id":"approve","text":{"type":"plain_text","text":"Approve"},"value":"2.0"},
        {"type":"button","action_id":"reject","text":{"type":"plain_text","text":"Reject"},"value":"2.0"}]},
      {"type":"synthetic_future_block","block_id":"future"}]},
    "actions":[{"type":"button","block_id":"decision","action_id":"approve","value":"2.0","action_ts":"1710000001.000100"}]}
    JSON

  def self.signed(payload : String) : HTTP::Request
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "Content-Type"              => "application/x-www-form-urlencoded",
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(SIGNING_SECRET, timestamp, body).compute,
    }
    HTTP::Request.new("POST", "/interactions", headers, body)
  end

  def self.run(output : IO = STDOUT) : Nil
    interaction = Slack::Interactions.parse(VERIFIER.verify(signed(CLICK)).body)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)
    message = interaction.message || raise "Missing source message"
    output.puts "Message #{message.ts}"
    message.blocks.each { |block| describe(block, output, "") }
  end

  private def self.describe(block : Slack::Interactions::ReceivedBlock, output : IO, indent : String) : Nil
    case block
    when Blocks::Header
      output.puts "#{indent}header: #{block.text.text}"
    when Blocks::Section
      output.puts "#{indent}section #{block.block_id}: #{block.text.try(&.text)} [#{block.accessory.try(&.action_id)}]"
    when Blocks::Actions
      output.puts "#{indent}actions #{block.block_id}: #{block.elements.compact_map(&.action_id).join(", ")}"
    when Blocks::Container
      output.puts "#{indent}container #{block.block_id}: #{block.title.try(&.text)}"
      block.child_blocks.each { |child| describe(child, output, indent + "  ") }
    when Slack::Interactions::RichText::Block
      output.puts "#{indent}rich_text #{block.block_id}: #{block.elements.size} element(s)"
    when Blocks::UnknownBlock
      output.puts "#{indent}skipped #{block.type}"
    else
      output.puts "#{indent}#{block.class.name.split("::").last.underscore} #{block.block_id}"
    end
  end
end
