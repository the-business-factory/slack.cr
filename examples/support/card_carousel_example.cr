require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Posts a carousel of department cards and handles a click on a card button.
# Card buttons send ordinary block_actions button payloads.
module OfflineCardCarouselExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  record Department, id : String, name : String, summary : String, icon : UI::CompositionObjects::SlackIconName

  DEPARTMENTS = [
    Department.new("mdr", "MDR", "Refining data files.", UI::CompositionObjects::SlackIconName::Code),
    Department.new("wellness", "Wellness Center", "Please wait until called.", UI::CompositionObjects::SlackIconName::Heart),
  ]

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted = JSON.parse(request.body || raise "Missing posted message")
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000400","message":{"type":"message","ts":"1710000000.000400","text":"Departments open for visits"}}))
    end

    message = UI.message(fallback_text: "Departments open for visits") do |builder|
      builder.carousel(DEPARTMENTS.map { |department| card(department) }, block_id: "departments")
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic-carousel", transport: OfflineExample::WebMockTransport.new)
    result = client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))
    output.puts "Posted #{DEPARTMENTS.size} cards to #{result.channel}/#{result.ts}"

    handle_click(output)

    begin
      UI::Blocks::Card.new(subtitle: UI.plain("A subtitle alone"))
    rescue error : UI::ValidationError
      output.puts "Rejected before sending: #{error.issues.map(&.code).join(", ")}"
    end
    body = posted
    raise "chat.postMessage was not called" unless body
    body
  end

  def self.card(department : Department) : UI::Blocks::Card
    UI::Blocks::Card.new(
      block_id: "department.#{department.id}",
      icon: UI::CompositionObjects::SlackIcon.new(department.icon),
      title: UI.plain(department.name),
      body: UI.plain(department.summary),
      actions: {UI::BlockElements::Button.new(text: UI.plain("Visit"), action_id: "visit.request",
        value: department.id, style: UI::BlockElements::ButtonStyle::Primary)}
    )
  end

  # Slack does not document which block_id a card button click carries, so the
  # handler reads only action_id and value.
  def self.handle_click(output : IO) : Nil
    payload = %({"type":"block_actions","team":null,"actions":[{"type":"button","block_id":"department.wellness","action_id":"visit.request","value":"wellness","action_ts":"1710000001.000100"}]})
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(SIGNING_SECRET, timestamp, body).compute,
    }
    interaction = Slack::Interactions.parse(VERIFIER.verify(HTTP::Request.new("POST", "/interactions", headers, body)).body)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)
    action = interaction.decoded_actions.first
    raise "Expected button action" unless action.is_a?(Slack::Interactions::ButtonAction)
    raise "Unexpected action" unless action.action_id == "visit.request"
    output.puts "Visit requested: #{action.value}"
  end
end
