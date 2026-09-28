require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineViewUpdateExample
  alias UI = Slack::UI

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    transport = OfflineExample::WebMockTransport.new
    token = "xoxb-synthetic-view-update"
    input = UI::Blocks::Input.new(label: UI.plain("Reason"), block_id: "reason",
      element: UI::BlockElements::PlainTextInput.new(action_id: "text", multiline: true))
    original = UI::FormModal.new(title: UI.plain("Request"), submit: UI.plain("Save"), blocks: {input})
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      expected = JSON.parse(<<-JSON)
        {"trigger_id":"synthetic-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Request"},
          "submit":{"type":"plain_text","text":"Save"},"blocks":[{"type":"input","block_id":"reason",
          "label":{"type":"plain_text","text":"Reason"},"element":{"type":"plain_text_input","action_id":"text","multiline":true}}]}}
        JSON
      raise "Incorrect opening request" unless JSON.parse(request.body || raise "Missing open request") == expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V123","type":"modal","hash":"opened-hash"}}))
    end
    opened = Slack::Api::ViewsOpen.new(token: token, trigger_id: "synthetic-trigger", view: original, transport: transport).call

    # Change display content while retaining the input's block_id and action_id.
    # The stub checks transmitted IDs, not Slack's preservation of a user's text.
    updated_view = UI::FormModal.new(title: UI.plain("Request"), submit: UI.plain("Save"), blocks: {
      UI::Blocks::Section.new(text: UI.plain("Add details before saving.")), input,
    })
    WebMock.stub(:post, "https://slack.com/api/views.update").to_return do |request|
      expected = JSON.parse(<<-JSON)
        {"view_id":"V123","hash":"opened-hash","view":{"type":"modal","title":{"type":"plain_text","text":"Request"},
          "submit":{"type":"plain_text","text":"Save"},"blocks":[
          {"type":"section","text":{"type":"plain_text","text":"Add details before saving."}},
          {"type":"input","block_id":"reason","label":{"type":"plain_text","text":"Reason"},
          "element":{"type":"plain_text_input","action_id":"text","multiline":true}}]}}
        JSON
      raise "Incorrect update or changed input IDs" unless JSON.parse(request.body || raise "Missing update request") == expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"view":{"id":"V123","type":"modal","hash":"next-hash"}}))
    end
    updated = Slack::Api::ViewsUpdate.new(token: token,
      view_id: opened.view["id"].as_s, hash: opened.view["hash"].as_s,
      view: updated_view, transport: transport).call
    output.puts "Updated modal #{updated.view["id"]} with stable reason/text input IDs (hash #{updated.view["hash"]})."
  end
end
