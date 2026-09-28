require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineRichTextInputExample
  alias UI = Slack::UI
  alias RT = UI::RichText
  alias Received = Slack::Interactions::RichText

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(SIGNING_SECRET, timestamp, body).compute,
    }
    Slack::Interactions.parse(VERIFIER.verify(HTTP::Request.new("POST", "/interactions", headers, body)).body)
  end

  # Publishes a Home standup composer, then reads two dispatched updates.
  # The second update has a malformed tree, which the handler skips.
  def self.run(output : IO = STDOUT) : Nil
    install_transport
    draft = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::Text.new("Yesterday: ")})})
    config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnEnterPressed])
    home = UI.home(callback_id: "standup") do |builder|
      builder.input(label: UI.plain("Standup"), block_id: "standup", dispatch_action: true,
        element: UI::BlockElements::RichTextInput.new(action_id: "summary", initial_value: draft,
          dispatch_action_config: config, placeholder: UI.plain("Mention the people you work with"), min_lines: 3))
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ViewsPublish.new(user_id: "U-AUTHOR", view: home))

    # Independent incoming payloads, not derived from the published view.
    summary = %({"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"Yesterday: paired with "},{"type":"user","user_id":"U-PAIR"}]},{"type":"rich_text_list","style":"bullet","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"Ship the release"}]}]}]})
    malformed = %({"type":"rich_text","elements":[{"type":"text","text":"not in a section"}]})
    {summary, malformed}.each do |tree|
      payload = %({"type":"block_actions","team":null,"container":{"type":"view","view_id":"V-HOME"},"actions":[{"type":"rich_text_input","block_id":"standup","action_id":"summary","action_ts":"1710000000.000001","rich_text_value":#{tree}}]})
      interaction = receive(payload)
      raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)
      begin
        action = interaction.decoded_actions.first
      rescue error : Slack::Interactions::TypeMismatch
        # Acknowledge with HTTP 200 anyway; the raw payload stays in interaction.actions.
        output.puts "Skipped malformed standup at #{error.path}"
        next
      end
      raise "Expected rich text input action" unless action.is_a?(Slack::Interactions::RichTextInputAction)
      tree = action.rich_text_value || next
      output.puts "Standup text: #{plain_text(tree)}"
      output.puts "Mentioned: #{mentioned_users(tree).join(", ")}"
    end
  end

  # Joins the text of each section and list item on its own line.
  def self.plain_text(block : Received::Block) : String
    block.elements.flat_map do |container|
      case container
      when Received::Section, Received::Quote, Received::Preformatted
        [inline_text(container.elements)]
      when Received::List
        container.elements.map { |item| "- #{inline_text(item.elements)}" }
      else
        [] of String
      end
    end.join(" / ")
  end

  def self.mentioned_users(block : Received::Block) : Array(String)
    block.elements.flat_map do |container|
      sections = case container
                 when Received::Section then [container]
                 when Received::List    then container.elements
                 else                        [] of Received::Section
                 end
      sections.flat_map { |section| section.elements.compact_map { |element| element.user_id if element.is_a?(Received::User) } }
    end
  end

  private def self.inline_text(elements : Array(Received::Element)) : String
    elements.join do |element|
      case element
      when Received::Text then element.text
      when Received::User then "@#{element.user_id}"
      else                     ""
      end
    end
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/views.publish").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing Home view")
      element = wire["view"]["blocks"][0]["element"]
      raise "Expected rich text input" unless element["type"].as_s == "rich_text_input"
      raise "Expected a rich text draft" unless element["initial_value"]["type"].as_s == "rich_text"
      HTTP::Client::Response.new(200, body: {ok: true, view: {id: "V-HOME", type: "home"}}.to_json)
    end
  end
end
