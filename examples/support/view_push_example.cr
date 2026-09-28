require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineViewPushExample
  alias UI = Slack::UI

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    transport = OfflineExample::WebMockTransport.new
    token = "xoxb-synthetic-view-push"
    original = UI.display_modal(title: UI.plain("Request 42")) do |builder|
      builder.actions(block_id: "request.actions", elements: {
        UI::BlockElements::Button.new(text: UI.plain("Add details"), action_id: "request.details"),
      })
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      expected = JSON.parse(<<-JSON)
        {"trigger_id":"opening-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Request 42"},
          "blocks":[{"type":"actions","block_id":"request.actions","elements":[
          {"type":"button","text":{"type":"plain_text","text":"Add details"},"action_id":"request.details"}]}]}}
        JSON
      raise "Incorrect opening request" unless JSON.parse(request.body || raise "Missing open request") == expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V1","type":"modal"}}))
    end
    client = Slack::Api::Client.new(token: token, transport: transport)
    opened = client.call(Slack::Api::ViewsOpen.new(trigger_id: "opening-trigger", view: original))

    # Synthetic, trusted fixture: a new interaction inside the opened modal.
    # Real HTTP handlers must verify the original request with Slack::Webhooks::Verifier.
    interaction = Slack::Interaction.from_json(<<-JSON)
      {"type":"block_actions","trigger_id":"fresh-modal-trigger","team":{"id":"T1"},"user":{"id":"U1"},
        "api_app_id":"A1","container":{"type":"view","view_id":"V1"},"view":{"id":"V1","type":"modal"},
        "actions":[{"type":"button","block_id":"request.actions","action_id":"request.details"}]}
      JSON
    case interaction
    when Slack::Interactions::BlockAction
      source = interaction.view || raise "Missing modal view"
      raise "Wrong source modal" unless source["id"] == opened.view["id"]
      action = interaction.decoded_actions.first
      raise "Unexpected action" unless action.is_a?(Slack::Interactions::ButtonAction) && action.action_id == "request.details"
      trigger = interaction.trigger_id || raise "Missing modal trigger"
      # A real handler sends this acknowledgment within three seconds, separately
      # from the API call, and uses the fresh trigger promptly.
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      next_view = UI.form_modal(title: UI.plain("Details"), submit: UI.plain("Save"),
        close: UI.plain("Back"), private_metadata: "42", callback_id: "request.details") do |builder|
        builder.input(label: UI.plain("Reason"), block_id: "reason",
          element: UI::BlockElements::PlainTextInput.new(action_id: "text", multiline: true))
      end
      WebMock.stub(:post, "https://slack.com/api/views.push").to_return do |request|
        expected = JSON.parse(<<-JSON)
          {"trigger_id":"fresh-modal-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Details"},
            "submit":{"type":"plain_text","text":"Save"},"close":{"type":"plain_text","text":"Back"},
            "private_metadata":"42","callback_id":"request.details","blocks":[{"type":"input","block_id":"reason",
            "label":{"type":"plain_text","text":"Reason"},"element":{"type":"plain_text_input","action_id":"text","multiline":true}}]}}
          JSON
        raise "Incorrect push request" unless JSON.parse(request.body || raise "Missing push request") == expected
        HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V2","type":"modal","root_view_id":"V1","previous_view_id":"V1"}}))
      end
      pushed = client.call(Slack::Api::ViewsPush.new(trigger_id: trigger, view: next_view))
      output.puts "Pushed details #{pushed.view["id"]} onto modal #{pushed.view["root_view_id"]} (acknowledged #{acknowledgement.status_code})."
    else
      raise "Expected modal block action"
    end
  end
end
